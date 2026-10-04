class DivisionTeamsController < ApplicationController
  before_action :require_login
  before_action :load_team_and_division_team

  # Drill-down from the Standings tab: show one division opponent's season
  # results (date, home/away, opponent, score), fetched live from Del-Tri.
  def show
    @results = []
    @error = nil

    if @division_team.source_url.present?
      begin
        @results = DeltriTeamResults.new(@division_team.source_url).call
      rescue StandardError => e
        @error = "Couldn't load results right now (#{e.message})."
      end
    else
      @error = "Results aren't available for this team yet."
    end
  end

  # GET /teams/:team_id/division_teams/:id/scorecard?d=09/14
  # The pop-up's body: that opponent's line-by-line result for one match,
  # read live from the league site. Rendered without the page layout.
  def scorecard
    @month_day = params[:d].to_s[%r{\A\d{2}/\d{2}\z}]
    @card = nil
    if @month_day && @division_team.source_url.present?
      begin
        @card = DeltriResults.new.card_for(@division_team.source_url, @division_team.name, @month_day)
      rescue StandardError => e
        @error = "Couldn't load this scorecard right now (#{e.message})."
      end
    end
    render layout: false
  end

  private

  def load_team_and_division_team
    @team = TennisTeam.find_by(id: params[:team_id])
    unless @team
      redirect_to teams_path, alert: "Team not found."
      return
    end
    unless member_of?(@team) || current_user.admin?
      redirect_to teams_path, alert: "You're not a member of that team."
      return
    end

    @division_team = @team.division_teams.find_by(id: params[:id])
    unless @division_team
      redirect_to team_path(@team), alert: "Team not found in the standings."
    end
  end

  def require_login
    redirect_to login_path, alert: "Please sign in first." unless current_user
  end

  def member_of?(team)
    team.team_memberships.exists?(user: current_user) || team.user_id == current_user.id
  end
end
