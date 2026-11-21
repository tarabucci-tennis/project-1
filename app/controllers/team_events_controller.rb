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

  # POST /teams/:team_id/events/:id/make_match — captain-only. A calendar
  # entry can't hold a score, so a league match added from the calendar
  # would keep the team's record at 0-0. This turns it into a real match
  # (same date, time and place), removes the calendar copy, and opens Edit
  # Match so the captain can check the opponent and home/away.
  def make_match
    unless @team.captain?(current_user) || current_user.admin?
      return redirect_back fallback_location: team_path(@team),
                           alert: "Only captains can turn an event into a match."
    end

    event = @team.team_events.find(params[:id])
    match = nil
    TeamEvent.transaction do
      match = @team.matches.create!(
        opponent:   self.class.opponent_from(event.title_without_side, @team.name),
        home_away:  event.side&.downcase,
        match_date: self.class.match_time_for(event.event_date, event.start_time),
        match_time: event.start_time,
        location:   event.location,
        notes:      event.notes
      )
      event.destroy!
    end
    redirect_to edit_team_match_path(@team, match),
                notice: "#{match.match_date.strftime('%b %-d')} is now a match. Check the opponent and home/away, then save."
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: team_path(@team), alert: "Couldn't make it a match: #{e.message}"
  end

  # "Over Served vs Smashers" / "vs. Smashers" → "Smashers"; anything else as is.
  def self.opponent_from(title, team_name)
    TeamEvent.opponent_from(title, team_name)
  end

  # Stored as the wall-clock time typed, like matches added with Add Match.
  # No usable time ("Morning", blank) → noon, so the match doesn't drop off
  # Upcoming at midnight.
  def self.match_time_for(date, start_time)
    text = start_time.to_s
    parsed = text.match?(/\d/) ? (Time.zone.parse("#{date} #{text}") rescue nil) : nil
    parsed || Time.zone.local(date.year, date.month, date.day, 12)
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
