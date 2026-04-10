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
  end

  def show
    @team = TennisTeam.includes(team_memberships: :user, matches: {}).find_by(id: params[:id])

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
    @is_captain       = @team.captain?(current_user)
    @wins             = @team.matches.where(result: "win").count
    @losses           = @team.matches.where(result: "loss").count
    @division_teams   = @team.division_teams.ranked

    # Build combined standings: your team + division opponents, sorted by wins desc
    @standings = []
    @standings << { name: @team.name, wins: @wins, losses: @losses, is_self: true }
    @division_teams.each do |dt|
      @standings << { name: dt.name, wins: dt.wins, losses: dt.losses, is_self: false }
    end
    @standings.sort_by! { |s| [-s[:wins], s[:losses], s[:name]] }

    # Captain analytics (only computed for captains)
    if @is_captain
      @player_analytics = build_player_analytics
      @doubles_pairings = build_doubles_pairings
    end

    # Load current user's availability for each match
    match_ids = (@upcoming_matches + @past_matches).map(&:id)
    @my_availabilities = Availability.where(user: current_user, match_id: match_ids).index_by(&:match_id)
  end

  private

  def require_login
    redirect_to login_path, alert: "Please sign in first." unless current_user
  end

  def member_of?(team)
    team.team_memberships.exists?(user: current_user) || team.user_id == current_user.id
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
