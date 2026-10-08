# The Ratings pages: every player's USTA match history (partners, opponents,
# scores), built from the TennisLink "Individual Result" files players upload.
# Any signed-in player can view and upload. Uploads only ever add lines.
class RatingsController < ApplicationController
  MAX_BYTES = 2.megabytes

  before_action :require_login

  # GET /ratings — everyone with saved USTA history.
  def index
    @players = UstaLine.player_summaries
    @users_by_name = users_by_name(@players.map(&:name))
  end

  # GET /ratings/player?name=Jane+Smith — one player's card + history.
  def show
    @name = params[:name].to_s.squish
    lines = @name.present? ? UstaLine.for_player(@name).order(match_date: :desc, position: :asc).to_a : []
    return redirect_to(ratings_path, alert: "No USTA history saved for that player yet.") if lines.empty?

    @entries = lines.filter_map { |l| l.entry_for(@name) }
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

  # Court Report users whose name matches, keyed by lowercased name — used for
  # their USTA level and profile link.
  def users_by_name(names)
    keys = names.map { |n| n.to_s.downcase.squish }.uniq
    return {} if keys.empty?
    User.where("LOWER(name) IN (?)", keys).index_by { |u| u.name.downcase.squish }
  end
end
