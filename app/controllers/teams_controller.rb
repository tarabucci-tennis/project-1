class TeamsController < ApplicationController
  before_action :require_login

  def index
    all_teams = current_user.member_teams.includes(:matches, :team_memberships)

    @teams_by_league = {
      "USTA"        => all_teams.select { |t| t.league_category == "USTA" },
      "Inter-Club"  => all_teams.select { |t| t.league_category == "Inter-Club" },
      "Local"       => all_teams.select { |t| t.league_category == "Local" }
    }

    # Fallback: include teams Tara owns even if she has no team_membership row
    if @teams_by_league.values.flatten.empty? && current_user.tennis_teams.any?
      owned = current_user.tennis_teams.order(start_date: :desc)
      @teams_by_league = {
        "USTA"        => owned.select { |t| t.league_category == "USTA" },
        "Inter-Club"  => owned.select { |t| t.league_category == "Inter-Club" },
        "Local"       => owned.select { |t| t.league_category == "Local" }
      }
    end

    # My upcoming matches across all teams (next 14 days)
    team_ids = all_teams.map(&:id)
    @upcoming_matches = Match.where(tennis_team_id: team_ids)
                             .where("match_date >= ? AND match_date <= ?", Time.current, 14.days.from_now)
                             .includes(:tennis_team, lineup: :lineup_slots)
                             .order(match_date: :asc)

    # Build a hash of match_id => line_label for the current user's lineup positions
    @my_lineup_lines = {}
    @upcoming_matches.each do |match|
      next unless match.lineup&.published?
      slot = match.lineup.lineup_slots.detect { |s| s.user_id == current_user.id }
      @my_lineup_lines[match.id] = slot.line_label if slot
    end
  end

  def show
    @team = TennisTeam.includes(team_memberships: :user, matches: :lineup).find_by(id: params[:id])

    unless @team
      redirect_to teams_path, alert: "Team not found."
      return
    end

    unless member_of?(@team) || current_user.admin?
      redirect_to teams_path, alert: "You're not a member of that team."
      return
    end

    @captain          = @team.captain
    @roster           = @team.team_memberships.includes(:user).sort_by { |m| [ m.captain? ? 0 : 1, m.user.name.to_s.downcase ] }
    @upcoming_matches = @team.matches.where("match_date >= ?", Time.current).order(match_date: :asc)
    @past_matches     = @team.matches.where("match_date < ?", Time.current).order(match_date: :desc)
    @player_count     = @team.team_memberships.count
    @is_captain       = @team.captain?(current_user) || current_user.admin?
    @wins             = @team.matches.where(result: "win").count
    @losses           = @team.matches.where(result: "loss").count
    @division_teams   = @team.division_teams.ranked

    # Build combined standings
    @is_points_league = @team.league_category == "Local"
    @standings = []

    if @is_points_league
      # Del-Tri uses points (total games won across the season)
      # Calculate Legacy 2's points from match scores
      my_points = @team.matches.where.not(score_summary: nil).sum { |m|
        m.score_summary.to_s.split("-").first.to_i
      }
      @standings << { name: @team.name, points: my_points, is_self: true }
      @division_teams.each do |dt|
        @standings << { name: dt.name, points: dt.wins, is_self: false }
      end
      @standings.sort_by! { |s| [-s[:points], s[:name]] }
    else
      # USTA-style standings (matches the TennisLink layout):
      #   Team · Matches Played · Points · Sets Won · Sets Lost · Games Won · Games Lost · Games Won %
      #
      # Our team's stats are computed live from match_lines as results
      # are entered. Division opponents currently show zeros — that data
      # isn't tracked yet. When we either (a) start scraping TennisLink
      # or (b) let captains manually enter opponent standings, it'll
      # populate the same row format.
      my_stats = compute_team_standings_stats(@team)
      @standings << my_stats.merge(name: @team.name, is_self: true)

      @division_teams.each do |dt|
        @standings << {
          name: dt.name,
          is_self: false,
          matches_played: (dt.wins + dt.losses),
          points: dt.wins * 2,  # USTA format: 2 pts per match win (rough)
          sets_won: 0,
          sets_lost: 0,
          games_won: 0,
          games_lost: 0,
          games_won_pct: 0.0
        }
      end

      # Sort: most points first, then matches played, then team name
      @standings.sort_by! { |s|
        [-s[:points].to_i, -s[:matches_played].to_i, s[:name]]
      }
    end

    # Player stats (visible to everyone on the Player Stats tab)
    @player_stats_data = build_player_analytics

    # Captain analytics (only computed for captains)
    if @is_captain
      @player_analytics = @player_stats_data
      @doubles_pairings = build_doubles_pairings
    end

    # Load current user's availability for each match
    match_ids = (@upcoming_matches + @past_matches).map(&:id)
    @my_availabilities = Availability.where(user: current_user, match_id: match_ids).index_by(&:match_id)
  end

  # GET /find-team — search for existing teams to join
  def search
    @query = params[:q].to_s.strip
    if @query.present?
      @results = TennisTeam.where("name LIKE ? OR section LIKE ?", "%#{@query}%", "%#{@query}%")
                           .order(:name)
                           .limit(20)
    else
      @results = []
    end
  end

  # GET /create-team — form to create a new team
  def new
    # Any logged-in user can create a team
  end

  # POST /create-team — create a new team
  def create
    team = current_user.tennis_teams.new(
      name: params[:name].to_s.strip,
      league_category: params[:league_category].presence || "USTA",
      team_type: params[:team_type].to_s.strip.presence,
      section: params[:section].to_s.strip.presence || "Middle States",
      gender: "F",
      season_name: params[:season_name].to_s.strip.presence
    )

    if team.save
      # Creator becomes captain
      TeamMembership.create!(user: current_user, tennis_team: team, role: "captain")
      redirect_to team_path(team), notice: "#{team.name} created! You're the captain."
    else
      flash.now[:alert] = team.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end
  end

  # POST /teams/:team_id/add_player — captain adds a player by email
  def add_player
    @team = TennisTeam.find(params[:team_id])
    unless @team.captain?(current_user) || current_user.admin?
      return redirect_to team_path(@team), alert: "Only captains can add players."
    end

    email = params[:email].to_s.downcase.strip
    name  = params[:player_name].to_s.strip

    if email.blank?
      return redirect_to team_path(@team), alert: "Please enter an email address."
    end

    player = User.find_by(email: email)
    if player.nil? && name.present?
      player = User.create!(name: name, email: email, admin: false)
    elsif player.nil?
      return redirect_to team_path(@team), alert: "No account found for #{email}. Enter their name too so we can create one."
    end

    if @team.team_memberships.exists?(user: player)
      redirect_to team_path(@team), notice: "#{player.name} is already on the team."
    else
      TeamMembership.create!(user: player, tennis_team: @team, role: "player")
      redirect_to team_path(@team), notice: "#{player.name} has been added to #{@team.name}!"
    end
  end

  private

  def require_login
    redirect_to login_path, alert: "Please sign in first." unless current_user
  end

  def member_of?(team)
    team.team_memberships.exists?(user: current_user) || team.user_id == current_user.id
  end

  # Compute TennisLink-style standings stats for a team from its
  # entered match results. Returns a hash with matches_played, points,
  # sets_won, sets_lost, games_won, games_lost, games_won_pct.
  #
  # Scores are assumed to be entered from OUR team's perspective:
  # "6-3" means our team won 6 games, opponent won 3 in that set.
  # All stats default to 0 if no results have been entered yet.
  def compute_team_standings_stats(team)
    completed = team.matches.completed.includes(:match_lines)

    stats = {
      matches_played: completed.count,
      points:         completed.where(result: "win").count * 2,
      sets_won:       0,
      sets_lost:      0,
      games_won:      0,
      games_lost:     0,
      games_won_pct:  0.0
    }

    completed.each do |match|
      match.match_lines.each do |line|
        [ line.set1_score, line.set2_score, line.set3_score ].each do |score|
          next if score.blank?

          # Strip tiebreak notation like "7-6(5)" → "7-6"
          cleaned = score.to_s.gsub(/\(.*?\)/, "").strip
          parts = cleaned.split(/[-–]/).map { |n| n.to_s.strip.to_i }
          next unless parts.size == 2

          our_games, their_games = parts
          stats[:games_won]  += our_games
          stats[:games_lost] += their_games
          if our_games > their_games
            stats[:sets_won] += 1
          else
            stats[:sets_lost] += 1
          end
        end
      end
    end

    total_games = stats[:games_won] + stats[:games_lost]
    if total_games > 0
      stats[:games_won_pct] = (stats[:games_won].to_f / total_games * 100).round(2)
    end

    stats
  end

  def build_player_analytics
    completed_matches = @team.matches.completed.includes(match_lines: { match_line_players: :user })
    return [] if completed_matches.empty?

    player_data = {}

    completed_matches.each do |match|
      match.match_lines.each do |line|
        line.match_line_players.each do |mlp|
          pd = player_data[mlp.user_id] ||= {
            name: mlp.user.name,
            matches_played: Set.new,
            singles: 0, doubles: 0,
            line_counts: Hash.new(0),
            wins: 0, losses: 0
          }
          pd[:matches_played].add(match.id)
          if line.line_type == "singles"
            pd[:singles] += 1
          else
            pd[:doubles] += 1
          end
          pd[:line_counts][line.line_label] += 1
          pd[:wins] += 1 if line.won?
          pd[:losses] += 1 if line.lost?
        end
      end
    end

    player_data.values.map do |pd|
      total_lines = pd[:singles] + pd[:doubles]
      total_results = pd[:wins] + pd[:losses]
      most_common = pd[:line_counts].max_by { |_, v| v }&.first

      {
        name: pd[:name],
        matches_played: pd[:matches_played].size,
        singles_pct: total_lines > 0 ? (pd[:singles].to_f / total_lines * 100).round(0) : 0,
        doubles_pct: total_lines > 0 ? (pd[:doubles].to_f / total_lines * 100).round(0) : 0,
        most_common_line: most_common,
        wins: pd[:wins],
        losses: pd[:losses],
        win_pct: total_results > 0 ? (pd[:wins].to_f / total_results * 100).round(0) : 0
      }
    end.sort_by { |p| -p[:matches_played] }
  end

  def build_doubles_pairings
    completed_matches = @team.matches.completed.includes(match_lines: { match_line_players: :user })
    return [] if completed_matches.empty?

    pairings = Hash.new { |h, k| h[k] = { wins: 0, losses: 0, played: 0 } }

    completed_matches.each do |match|
      match.match_lines.where(line_type: "doubles").each do |line|
        players = line.match_line_players.includes(:user).map(&:user).sort_by(&:name)
        next if players.size < 2
        key = players.map(&:name).join(" & ")
        pairings[key][:played] += 1
        pairings[key][:wins] += 1 if line.won?
        pairings[key][:losses] += 1 if line.lost?
      end
    end

    pairings.map do |names, data|
      total = data[:wins] + data[:losses]
      {
        names: names,
        played: data[:played],
        wins: data[:wins],
        losses: data[:losses],
        win_pct: total > 0 ? (data[:wins].to_f / total * 100).round(0) : 0
      }
    end.sort_by { |p| [-p[:played], -p[:win_pct]] }
  end
end
