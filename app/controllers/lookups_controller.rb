class LookupsController < ApplicationController
  before_action :require_login

  # GET /lookup — search & browse the players and teams inside YOUR leagues.
  #
  # This is deliberately scoped to the leagues the current user actually plays
  # in (their competitive world), not a copy of all of USTA. It reuses data
  # Court Report already holds: team rosters, live Court Report ratings, and
  # the opponent standings we pull from each league's public site.
  def index
    @query = params[:q].to_s.strip

    # The leagues you play in, keyed by their real name ("USTA", "Del-Tri", …).
    my_teams = current_user.member_teams.to_a
    my_teams = current_user.tennis_teams.to_a if my_teams.empty?
    @league_labels = my_teams.map(&:league_label).uniq

    # Every Court Report team that plays in one of your leagues.
    league_teams = TennisTeam.includes(:matches, team_memberships: :user)
                             .to_a
                             .select { |t| @league_labels.include?(t.league_label) }
    my_team_ids = my_teams.map(&:id).to_set

    # ── Players: everyone rostered on a team in your leagues ──────────────
    seen = {}
    league_teams.each do |team|
      team.team_memberships.each do |m|
        next if m.archived_season.present?
        user = m.user
        next unless user
        entry = seen[user.id] ||= { user: user, team_names: [] }
        entry[:team_names] << team.name
      end
    end

    @players = seen.values.map do |entry|
      user = entry[:user]
      record = user.live_line_record
      {
        user: user,
        ycr: user.court_report_rating,
        ntrp: user.ntrp_rating,
        teams: entry[:team_names].uniq.sort,
        won: record[:won],
        lost: record[:lost],
        total: record[:total]
      }
    end

    @players = filter_by_name(@players) { |p| p[:user].name }
    # Rated players first (highest YCR), then everyone else alphabetically.
    @players.sort_by! do |p|
      [ p[:ycr] ? 0 : 1, -(p[:ycr] || 0).to_f, p[:user].name.to_s.downcase ]
    end

    # ── Teams: your own teams, plus opponents in your divisions ───────────
    @my_teams_list = filter_by_name(my_teams.sort_by { |t| t.name.to_s.downcase }, &:name)

    # Opponent teams come from the standings we already pull for each league.
    # Dedupe by name so a team you also play doesn't show twice, and skip the
    # rows that ARE your own teams.
    my_team_names = my_teams.map { |t| normalize(t.name) }.to_set
    opponents = {}
    DivisionTeam.includes(:tennis_team).find_each do |dt|
      parent = dt.tennis_team
      next unless parent && @league_labels.include?(parent.league_label)
      key = normalize(dt.name)
      next if my_team_names.include?(key)
      opponents[key] ||= {
        name: dt.name,
        league: parent.league_label,
        points: dt.points,
        wins: dt.wins,
        losses: dt.losses,
        position: dt.position
      }
    end
    @opponent_teams = filter_by_name(opponents.values) { |t| t[:name] }
    @opponent_teams.sort_by! { |t| [ t[:position] || 999, t[:name].to_s.downcase ] }
  end

  private

  def require_login
    redirect_to login_path unless current_user
  end

  def filter_by_name(list)
    return list if @query.blank?
    needle = @query.downcase
    list.select { |item| yield(item).to_s.downcase.include?(needle) }
  end

  def normalize(str)
    str.to_s.strip.downcase.gsub(/\s+/, " ")
  end
end
