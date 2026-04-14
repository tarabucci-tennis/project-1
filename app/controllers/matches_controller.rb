class MatchesController < ApplicationController
  before_action :require_login
  before_action :set_team
  before_action :require_membership

  def index
    @matches = @team.matches.chronological
    @is_captain = @team.captain?(current_user)
  end

  def show
    @match = @team.matches.find(params[:id])
    @lineup = @match.lineup
    @is_captain = @team.captain?(current_user) || @team.user_id == current_user.id
    @my_availability = @match.availability_for(current_user)

    if @lineup&.published?
      @slots = @lineup.lineup_slots.includes(:user).order(position: :asc)
    end
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

    # Pre-populate player dropdowns from the published lineup so captains
    # don't have to re-pick the same names they already set in Set Lineup.
    # Only runs for match_lines that currently have ZERO players — once the
    # captain has saved at least one player on a line, we respect their
    # choice and don't auto-fill anymore (so subs stick).
    populate_players_from_lineup(@match) if @match.lineup&.published?

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

  # Copy players from the published lineup into match_line_players, so the
  # Enter Results form shows pre-filled dropdowns instead of empty ones.
  #
  # Mapping: lineup_slot positions are 1-based within line_type (singles=1,
  # doubles=1..4). match_line positions are offset by the number of singles
  # lines because match_lines has a unique index on [match_id, position] —
  # so for USTA, lineup doubles pos 1 maps to match_line doubles pos 2, etc.
  #
  # Only populates match_lines that currently have ZERO players, so once
  # the captain has saved changes to a line (e.g. swapped in a sub), we
  # respect that and don't auto-overwrite on subsequent page loads.
  def populate_players_from_lineup(match)
    lineup = match.lineup
    return unless lineup

    singles_offset = match.match_lines.where(line_type: "singles").count

    lineup.lineup_slots.where.not(user_id: nil).find_each do |slot|
      match_line_position =
        if slot.line_type == "singles"
          slot.position
        else
          slot.position + singles_offset
        end

      match_line = match.match_lines.find_by(line_type: slot.line_type, position: match_line_position)
      next unless match_line
      next if match_line.match_line_players.any?  # respect captain's edits

      match_line.match_line_players.create!(user_id: slot.user_id)
    end
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
