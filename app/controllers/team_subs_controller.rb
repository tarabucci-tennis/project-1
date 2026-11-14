# The Subs tab on a team page: captains (and co-captains, admins) keep a list
# of subs. Adding a name reuses the person if Court Report already knows them.
class TeamSubsController < ApplicationController
  before_action :require_login
  before_action :set_team
  before_action :require_lineup_setter

  # POST /teams/:team_id/subs — add by name (or save someone who already subbed)
  def create
    user = if params[:user_id].present?
      User.find_by(id: params[:user_id])
    else
      name = params[:name].to_s.squish.first(60)
      return back_to_subs(alert: "Type the sub's name first.") if name.blank?
      User.where("LOWER(name) = ?", name.downcase).first || User.create!(name: name)
    end
    return back_to_subs(alert: "Couldn't find that player.") unless user

    if @team.team_memberships.active.exists?(user: user)
      return back_to_subs(alert: "#{user.name} is already on the roster.")
    end

    sub = @team.team_subs.find_or_initialize_by(user: user)
    sub.note = params[:note].to_s.squish.first(80).presence if params.key?(:note)
    sub.added_by ||= current_user
    if sub.save
      back_to_subs(notice: "#{user.name} is on the Subs list.")
    else
      back_to_subs(alert: sub.errors.full_messages.to_sentence)
    end
  end

  # DELETE /teams/:team_id/subs/:id — take a saved sub off the list
  def destroy
    sub = @team.team_subs.find_by(id: params[:id])
    sub&.destroy
    back_to_subs(notice: sub ? "#{sub.user.name} was taken off the Subs list." : nil)
  end

  private

  def set_team
    @team = TennisTeam.find_by(id: params[:team_id])
    redirect_to teams_path, alert: "Team not found." unless @team
  end

  def require_lineup_setter
    return if current_user.admin? || @team.can_set_lineup?(current_user)
    redirect_to team_path(@team, tab: "subs"), alert: "Only captains and co-captains can change the Subs list."
  end

  def require_login
    redirect_to login_path, alert: "Please sign in first." unless current_user
  end

  def back_to_subs(**flash)
    redirect_to team_path(@team, tab: "subs"), **flash.compact
  end
end
