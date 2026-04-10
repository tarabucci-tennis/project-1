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

  def edit_results
    @match = @team.matches.find(params[:id])
    @members = @team.members.order(:name)

    # Build empty lines if none exist yet (USTA 40+: 1 singles + 4 doubles)
    if @match.match_lines.empty?
      build_default_lines(@match)
    end

    @match_lines = @match.match_lines.includes(:players).order(position: :asc)
  end

  def update_results
    @match = @team.matches.find(params[:id])

    ActiveRecord::Base.transaction do
      # Update overall match result
      @match.update!(
        result: params[:match_result],
        score_summary: params[:score_summary]
      )

      # Update each line
      if params[:lines].present?
        params[:lines].each do |line_id, line_data|
          line = @match.match_lines.find(line_id)
          line.update!(
            result: line_data[:result].presence,
            set1_score: line_data[:set1_score].presence,
            set2_score: line_data[:set2_score].presence,
            set3_score: line_data[:set3_score].presence
          )

          # Update players on this line
          line.match_line_players.destroy_all
          if line_data[:player_ids].present?
            line_data[:player_ids].reject(&:blank?).each do |player_id|
              line.match_line_players.create!(user_id: player_id)
            end
          end
        end
      end

      # Auto-calculate score summary from lines
      if @match.match_lines.where.not(result: nil).any?
        won = @match.lines_won
        lost = @match.lines_lost
        @match.update!(score_summary: "#{won}-#{lost}")
      end
    end

    redirect_to team_path(@team), notice: "Match results saved!"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to edit_results_team_match_path(@team, @match), alert: "Error saving results: #{e.message}"
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

  def build_default_lines(match)
    # Default USTA format: 1 singles + 4 doubles
    MatchLine.create!(match: match, line_type: "singles", position: 1)
    MatchLine.create!(match: match, line_type: "doubles", position: 2)
    MatchLine.create!(match: match, line_type: "doubles", position: 3)
    MatchLine.create!(match: match, line_type: "doubles", position: 4)
    MatchLine.create!(match: match, line_type: "doubles", position: 5)
  end

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
