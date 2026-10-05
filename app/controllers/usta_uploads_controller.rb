# Any player on a USTA team can upload the team's TennisLink "Team Summary"
# export (Stats & Standings → Send To Excel). We show a preview of what will
# change, then save it with UstaTeamSummaryImport. The uploaded file is held
# in the cache between the preview and the save, keyed by a random token.
class UstaUploadsController < ApplicationController
  MAX_BYTES = 2.megabytes

  before_action :require_login
  before_action :load_team

  # GET /teams/:id/usta_upload
  def new
  end

  # POST /teams/:id/usta_upload — parse the file and show the preview.
  def preview
    file = params[:file]
    if file.blank?
      return redirect_to usta_upload_team_path(@team), alert: "Choose the Team Summary file first."
    end
    if file.size > MAX_BYTES
      return redirect_to usta_upload_team_path(@team), alert: "That file is too big to be a TennisLink export."
    end

    html = file.read.to_s.force_encoding("UTF-8").scrub
    parsed = UstaTeamSummaryParser.parse(html)
    unless parsed.summary_file?
      return redirect_to usta_upload_team_path(@team),
                         alert: "That doesn't look like a TennisLink Team Summary. On TennisLink open your team's Stats & Standings and tap \"Send To Excel\"."
    end

    @token = SecureRandom.hex(16)
    Rails.cache.write(cache_key(@token), html, expires_in: 30.minutes)
    @parsed = parsed
    @plan = UstaTeamSummaryImport.new(@team, parsed).plan
    render :preview
  end

  # POST /teams/:id/usta_upload/confirm — save it.
  def create
    html = Rails.cache.read(cache_key(params[:token].to_s))
    if html.blank?
      return redirect_to usta_upload_team_path(@team), alert: "That upload expired — please choose the file again."
    end

    UstaTeamSummaryImport.new(@team, UstaTeamSummaryParser.parse(html)).apply!
    Rails.cache.delete(cache_key(params[:token].to_s))
    redirect_to team_path(@team, anchor: "standings"), notice: "USTA standings, scores and ratings updated."
  end

  private

  def load_team
    @team = TennisTeam.find_by(id: params[:id])
    return redirect_to(teams_path, alert: "Team not found.") unless @team

    unless @team.team_memberships.exists?(user: current_user) || @team.user_id == current_user.id || current_user.admin?
      redirect_to teams_path, alert: "You're not a member of that team."
    end
  end

  def cache_key(token)
    [ "usta-upload", @team.id, current_user.id, token ]
  end

  def require_login
    redirect_to login_path, alert: "Please sign in first." unless current_user
  end
end
