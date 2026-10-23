# GET /search?q= — the search box in the top bar. Finds anything a signed-in
# player can already see: pages of the site, their teams, players and other
# teams in their leagues, their matches (by opponent or club) and their
# friendlies. Nothing outside the player's own leagues is searched.
class SearchesController < ApplicationController
  before_action :require_login

  LIMIT = 12

  # Site pages, matched on their title and a few extra words.
  def self.pages(helpers, admin:)
    list = [
      [ "My Teams", "Your teams, standings and calendar", helpers.teams_path, "home teams" ],
      [ "Standings", "Every team's record", helpers.teams_path(tab: "standings"), "standings record wins losses table" ],
      [ "Calendar", "Matches, clinics and friendlies by day", helpers.teams_path(tab: "calendar"), "calendar schedule month" ],
      [ "Upcoming", "What's next for your teams", helpers.teams_path(tab: "upcoming"), "upcoming next schedule matches" ],
      [ "Book a friendly", "Set up a friendly and share the link", helpers.new_friendly_path, "friendly friendlies book" ],
      [ "My friendlies", "Friendlies you organized or joined", helpers.friendlies_path, "friendly friendlies" ],
      [ "Lineups", "Lineups for your upcoming matches", helpers.lineups_dashboard_path, "lineup lineups" ],
      [ "Players & Teams", "Everyone in your leagues", helpers.lookup_path, "players teams roster lookup" ],
      [ "My profile", "Your rating, record and teams", helpers.profile_path, "profile me rating record" ],
      [ "Find a team", "Search for a team to join", helpers.find_team_path, "join find team" ],
      [ "Create a team", "Start a new team", helpers.new_team_path, "create new team" ]
    ]
    list << [ "Ratings", "Players' USTA match history", helpers.ratings_path, "ratings rating ntrp usta" ] if RatingsController::PUBLIC || admin
    list.map { |title, note, url, words| { title: title, note: note, url: url, words: "#{title} #{words}".downcase } }
  end

  def index
    @query = params[:q].to_s.squish.first(80)
    return if @query.blank?

    needle = @query.downcase
    like = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"

    @pages = self.class.pages(helpers, admin: current_user.admin?)
                 .select { |p| needle.split.all? { |w| p[:words].include?(w) } }

    my_teams = (current_user.member_teams.to_a + current_user.tennis_teams.to_a).uniq
    my_ids = my_teams.map(&:id).to_set
    leagues = my_teams.map(&:league_label).uniq
    league_teams = TennisTeam.all.to_a.select { |t| my_ids.include?(t.id) || leagues.include?(t.league_label) }

    @my_teams = my_teams.select { |t| t.name.to_s.downcase.include?(needle) }.sort_by { |t| t.name.to_s.downcase }
    @other_teams = league_teams.reject { |t| my_ids.include?(t.id) }
                               .select { |t| t.name.to_s.downcase.include?(needle) }
                               .sort_by { |t| t.name.to_s.downcase }.first(LIMIT)

    @players = User.joins(:team_memberships)
                   .where(team_memberships: { tennis_team_id: league_teams.map(&:id), archived_season: nil })
                   .where("users.name LIKE ?", like).distinct.order(:name).limit(LIMIT).to_a

    @matches = Match.where(tennis_team_id: my_ids.to_a)
                    .where("matches.opponent LIKE ? OR matches.location LIKE ?", like, like)
                    .includes(:tennis_team).to_a
                    .sort_by { |m| [ m.match_date < Time.current ? 1 : 0, (m.match_date - Time.current).abs ] }
                    .first(LIMIT)

    @friendlies = Friendly.involving(current_user)
                          .where("friendlies.title LIKE ? OR friendlies.location LIKE ?", like, like)
                          .order(starts_at: :desc).limit(LIMIT).to_a

    @total = @pages.size + @my_teams.size + @other_teams.size + @players.size + @matches.size + @friendlies.size
  end

  private

  def require_login
    redirect_to login_path unless current_user
  end
end
