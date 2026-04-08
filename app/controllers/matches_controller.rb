class MatchesController < ApplicationController
  before_action :require_login
  before_action :set_team
  before_action :require_membership

  def index
    @matches = @team.matches.chronological
    @is_captain = @team.captain?(current_user)
  end

  def new
    unless @team.captain?(current_user)
      return redirect_to team_matches_path(@team), alert: "Only captains can add matches."
    end
    @match = @team.matches.new
  end

  def create
    unless @team.captain?(current_user)
      return redirect_to team_matches_path(@team), alert: "Only captains can add matches."
    end

    @match = @team.matches.new(match_params)
    if @match.save
      redirect_to team_matches_path(@team), notice: "Match added to schedule."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def captain
    unless @team.captain?(current_user)
      return redirect_to team_matches_path(@team), alert: "Only captains can view this."
    end

    @matches = @team.matches.chronological
    @members = @team.members.order(:name)
    @availability_map = build_availability_map
  end

  private

  def set_team
    @team = TennisTeam.find_by(id: params[:team_id])
    redirect_to teams_path, alert: "Team not found." unless @team
  end

  def require_membership
    return if @team&.team_memberships&.exists?(user: current_user)
    redirect_to teams_path, alert: "You're not a member of this team."
  end

  def require_login
    redirect_to login_path, alert: "Please sign in first." unless current_user
  end

  def match_params
    params.require(:match).permit(:match_date, :location, :opponent, :notes)
  end

  def build_availability_map
    # Build a hash: { user_id => { match_id => availability } }
    map = {}
    @members.each { |m| map[m.id] = {} }

    Availability.where(match: @matches, user: @members).find_each do |a|
      map[a.user_id] ||= {}
      map[a.user_id][a.match_id] = a
    end

    map
  end
end
