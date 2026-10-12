# Add a whole USTA team from its TennisLink "Team Summary" export: upload the
# file, pick which team in the standings is yours, check the preview, save.
# Any signed-in player can add a team they're on. The file is held in the
# cache between the preview and the save, keyed by a random token.
class UstaTeamsController < ApplicationController
  MAX_BYTES = 2.megabytes

  before_action :require_login

  # GET /usta-teams/new
  def new
  end

  # POST /usta-teams/preview
  def preview
    file = params[:file]
    return redirect_to(new_usta_team_path, alert: "Choose the Team Summary file first.") if file.blank?
    return redirect_to(new_usta_team_path, alert: "That file is too big to be a TennisLink export.") if file.size > MAX_BYTES

    html = file.read.to_s.force_encoding("UTF-8").scrub
    @parsed = UstaTeamSummaryParser.parse(html)
    if @parsed.standings.empty?
      return redirect_to new_usta_team_path,
                         alert: "That doesn't look like a TennisLink Team Summary. On TennisLink open the team's Stats & Standings and tap \"Send To Excel\"."
    end

    @token = SecureRandom.hex(16)
    Rails.cache.write(cache_key(@token), html, expires_in: 30.minutes)
    # Guess the uploader's team from the teams they're already on: an exact
    # name match, else a new season of one ("Kiss My Ace" -> "Kiss My Ace
    # Winter"). They can change it.
    mine = TennisTeam.joins(:team_memberships).where(team_memberships: { user_id: current_user.id })
                     .pluck(:name).map { |n| n.to_s.downcase }
    names = @parsed.standings.map(&:name)
    @suggested = names.detect { |n| mine.include?(n.downcase) } ||
                 names.detect { |n| mine.any? { |m| m.present? && n.downcase.start_with?(m) } }
  end

  # POST /usta-teams
  def create
    html = Rails.cache.read(cache_key(params[:token].to_s))
    return redirect_to(new_usta_team_path, alert: "That upload expired — please choose the file again.") if html.blank?

    parsed = UstaTeamSummaryParser.parse(html)
    name = params[:team_name].to_s
    unless parsed.standings.any? { |s| s.name == name }
      return redirect_to new_usta_team_path, alert: "Pick your team from the list."
    end

    team = UstaTeamCreator.new(parsed, team_name: name, user: current_user).call
    Rails.cache.delete(cache_key(params[:token].to_s))
    redirect_to team_path(team), notice: "#{team.name} is set up: schedule, standings and roster from TennisLink."
  end

  private

  def cache_key(token)
    [ "usta-team-upload", current_user.id, token ]
  end

  def require_login
    redirect_to login_path, alert: "Please sign in first." unless current_user
  end
end
