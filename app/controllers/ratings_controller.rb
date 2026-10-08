# The Ratings pages: every player's USTA match history (partners, opponents,
# scores). Fed automatically by scores entered on Court Report; captains can
# also upload TennisLink "Individual Result" files for older matches.
# Any signed-in player can view. Uploads only ever add lines.
class RatingsController < ApplicationController
  MAX_BYTES = 2.megabytes

  before_action :require_login
  before_action :require_uploader, only: [ :new, :create ]
  helper_method :can_upload?

  # GET /ratings — everyone with saved USTA history.
  def index
    @players = RatingsHistory.player_summaries
    @users_by_name = users_by_name(@players.map(&:name))
  end

  # GET /ratings/player?name=Jane+Smith — one player's card + history.
  def show
    @name = params[:name].to_s.squish
    @entries = @name.present? ? RatingsHistory.entries_for(@name) : []
    return redirect_to(ratings_path, alert: "No USTA history saved for that player yet.") if @entries.empty?
    # Show the name the way TennisLink prints it.
    @name = @entries.first.line.players.find { |n| n.downcase.squish == @name.downcase } || @name
    @user = users_by_name([ @name ])[@name.downcase]
    @wins = @entries.count(&:won)
    @losses = @entries.size - @wins
  end

  # GET /ratings/upload
  def new
  end

  # POST /ratings/upload — save an Individual Result file.
  def create
    file = params[:file]
    return redirect_to(ratings_upload_path, alert: "Choose your USTA results file first.") if file.blank?
    return redirect_to(ratings_upload_path, alert: "That file is too big to be a TennisLink export.") if file.size > MAX_BYTES

    html = file.read.to_s.force_encoding("UTF-8").scrub
    result = UstaResultsParser.parse(html)
    if result.leagues.empty?
      return redirect_to ratings_upload_path,
                         alert: "No results found in that file. On TennisLink open your Individual Player Record and tap \"Send To Excel\"."
    end

    counts = UstaLine.import(result, uploaded_by: current_user)
    target = result.player_name.present? ? ratings_player_path(name: result.player_name) : ratings_path
    notice = "Saved #{counts[:added]} new #{'line'.pluralize(counts[:added])}."
    notice += " #{counts[:existing]} were already saved from a teammate's file." if counts[:existing].positive?
    redirect_to target, notice: notice
  rescue StandardError => e
    redirect_to ratings_upload_path, alert: "Couldn't read that file (#{e.message})."
  end

  private

  def require_login
    redirect_to login_path, alert: "Please sign in first." unless current_user
  end

  # Uploading TennisLink files is a captain's option (plus admins).
  def can_upload?
    return false unless current_user
    current_user.admin? ||
      TeamMembership.active.leaders.exists?(user: current_user) ||
      TennisTeam.exists?(user: current_user)
  end

  def require_uploader
    redirect_to ratings_path, alert: "Uploading TennisLink files is a captain option." unless can_upload?
  end

  # Court Report users whose name matches, keyed by lowercased name — used for
  # their USTA level and profile link.
  def users_by_name(names)
    keys = names.map { |n| n.to_s.downcase.squish }.uniq
    return {} if keys.empty?
    User.where("LOWER(name) IN (?)", keys).index_by { |u| u.name.downcase.squish }
  end
end
