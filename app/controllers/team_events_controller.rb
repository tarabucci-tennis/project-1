class TeamEventsController < ApplicationController
  before_action :require_login
  before_action :set_team

  def create
    unless @team.can_set_lineup?(current_user) || current_user.admin?
      return redirect_back fallback_location: teams_path,
                           alert: "Only captains and co-captains can add team events."
    end

    kind = params[:kind].to_s.strip.presence || "friendly"
    if kind == "other"
      kind = params[:kind_other].to_s.squish.presence
      unless kind
        return redirect_back fallback_location: teams_path,
                             alert: "Type what it is (e.g. Lesson) next to \"Something else\"."
      end
    end

    event = @team.team_events.new(
      title:      params[:title].to_s.strip.presence || default_title_for(kind),
      event_date: params[:event_date],
      start_time: params[:start_time].to_s.strip.presence,
      location:   params[:location].to_s.strip.presence,
      kind:       kind,
      notes:      params[:notes].to_s.strip.presence
    )

    if event.save
      redirect_back fallback_location: teams_path,
                    notice: "#{event.kind_label} added for #{event.event_date.strftime('%b %-d')}."
    else
      redirect_back fallback_location: teams_path,
                    alert: "Couldn't add event: #{event.errors.full_messages.join(', ')}"
    end
  end

  def destroy
    unless @team.can_set_lineup?(current_user) || current_user.admin?
      return redirect_back fallback_location: teams_path,
                           alert: "Only captains and co-captains can remove team events."
    end

    event = @team.team_events.find(params[:id])
    event.destroy
    redirect_back fallback_location: teams_path, notice: "Event removed."
  end

  private

  def set_team
    @team = TennisTeam.find(params[:team_id])
  end

  def require_login
    redirect_to login_path, alert: "Please sign in first." unless current_user
  end

  def default_title_for(kind)
    case kind.to_s
    when "clinic" then "Team Clinic"
    when "friendly", "practice" then "Friendly Match"
    else kind.to_s
    end
  end
end
