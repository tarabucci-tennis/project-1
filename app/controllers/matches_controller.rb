class MatchesController < ApplicationController
  before_action :require_login
  before_action :set_team
  before_action :require_membership
  before_action :require_results_editor, only: [ :edit_results, :update_results ]

  def index
    @matches = @team.matches.chronological
    @is_captain = @team.captain?(current_user)
  end

  def show
    @match = @team.matches.find(params[:id])
    @lineup = @match.lineup
    @is_captain = @team.captain?(current_user) || @team.user_id == current_user.id
    @can_enter_results = @team.can_enter_results?(current_user)
    # Players on a line enter just their own line; captains use the full form.
    @can_enter_my_line = !@can_enter_results && @match.started? && @match.on_a_line?(current_user)
    @my_availability = @match.availability_for(current_user)

    if @lineup&.published?
      @slots = @lineup.lineup_slots.includes(:user).order(position: :asc)
    end
  end

  def new
    unless @team.captain?(current_user)
      return redirect_to team_matches_path(@team), alert: "Only captains can add matches."
    end
    @match = @team.matches.new(playoff_level: @team.playoff_level)
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

  def edit
    @match = @team.matches.find(params[:id])
    unless @team.captain?(current_user) || current_user.admin?
      redirect_to team_path(@team), alert: "Only captains can edit match details."
    end
  end

  def update
    @match = @team.matches.find(params[:id])
    unless @team.captain?(current_user) || current_user.admin?
      return redirect_to team_path(@team), alert: "Only captains can edit match details."
    end

    if @match.update(match_params)
      redirect_to team_path(@team), notice: "Match updated."
    else
      flash.now[:alert] = @match.errors.full_messages.join(", ")
      render :edit, status: :unprocessable_entity
    end
  end

  def edit_results
    @match = @team.matches.find(params[:id])
    @members = @team.members.order(:name)

    # Build empty lines if none exist yet, in the team's format (USTA 1S+4D,
    # Tri-Level 3 doubles, Del-Tri / Cup 6 doubles). Lines built earlier in
    # the wrong format are rebuilt as long as nothing was entered on them.
    rebuild_unused_lines(@match) if wrong_layout?(@match)
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

  # GET /teams/:team_id/matches/:id/my_line — a player enters just her own
  # line's score (Tara, Nov 17 2026). Her line = the one she's on in the
  # saved scores, or in the posted lineup. Captains can still change it all.
  def edit_my_line
    @match = @team.matches.find(params[:id])
    @line = my_line_for(@match, current_user)
    return redirect_to(team_match_path(@team, @match), alert: "You're not on a line for this match.") unless @line
    @partner_options = partner_options(@line)
  end

  def update_my_line
    @match = @team.matches.find(params[:id])
    @line = my_line_for(@match, current_user)
    return redirect_to(team_match_path(@team, @match), alert: "You're not on a line for this match.") unless @line

    data = params[:line] || {}
    mode = LineScoring.mode_for(@team)
    ActiveRecord::Base.transaction do
      sets = (1..3).map { |n| set_string(data, n, @line.public_send("set#{n}_score")) }
      result = data[:result].presence || LineScoring.line_result(LineScoring.parse_sets(sets), mode)
      @line.update!(result: result, set1_score: sets[0], set2_score: sets[1], set3_score: sets[2],
                    opponents: data[:opponents].to_s.strip.presence,
                    entered_by: current_user, entered_at: Time.current)

      # Players: always her; her partner as picked (doubles).
      ids = [ current_user.id ]
      ids << data[:partner_id].to_i if @line.line_type == "doubles" && data[:partner_id].present?
      @line.match_line_players.where.not(user_id: ids).destroy_all
      ids.uniq.each { |id| @line.match_line_players.find_or_create_by!(user_id: id) }

      fill_team_result(@match, mode)
    end

    redirect_to team_match_path(@team, @match), notice: "Saved your line. Thanks!"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to my_line_team_match_path(@team, @match), alert: "Couldn't save: #{e.message}"
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
            set3_score: line_data[:set3_score].presence,
            opponents: line_data[:opponents].to_s.strip.presence
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

    # Ratings update the instant a result is saved.
    RatingCalculator.recompute!

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

  # The line `user` plays on in `match`: from the saved scores, or from the
  # posted lineup (blank lines are made in the team's format, as Enter
  # Results does). nil if she isn't on a line.
  def my_line_for(match, user)
    line = match.match_lines.joins(:match_line_players).find_by(match_line_players: { user_id: user.id })
    return line if line
    return nil unless match.lineup&.published? && match.lineup.lineup_slots.exists?(user_id: user.id)

    rebuild_unused_lines(match) if wrong_layout?(match)
    build_default_lines(match) if match.match_lines.empty?
    populate_players_from_lineup(match)
    match.match_lines.joins(:match_line_players).find_by(match_line_players: { user_id: user.id })
  end

  # Partner choices: the current partner first, then the roster, then subs.
  def partner_options(line)
    current = line.match_line_players.includes(:user).map(&:user).compact
    roster = @team.team_memberships.active.includes(:user).map(&:user).compact
    subs = @team.team_subs.includes(:user).map(&:user).compact
    (current + roster.sort_by { |u| u.name.to_s.downcase } + subs.sort_by { |u| u.name.to_s.downcase })
      .uniq(&:id).reject { |u| u.id == current_user.id }
  end

  # Once every line that has players has a W/L, fill in the team result —
  # but never over a result someone already set.
  def fill_team_result(match, mode)
    lines = match.match_lines.reload.includes(:match_line_players).to_a
    if lines.any? { |l| l.result.present? }
      match.update!(score_summary: "#{lines.count(&:won?)}-#{lines.count(&:lost?)}")
    end
    return if match.result.present?
    played = lines.select { |l| l.match_line_players.any? || l.scored? }
    return if played.empty? || played.any? { |l| l.result.blank? }
    # Wait for the full match: as many decided lines as the league plays
    # (a half-posted lineup mustn't decide the team result early).
    return if played.size < default_line_types(match).size

    summary = played.map { |l| { result: l.result, sets: LineScoring.parse_sets([ l.set1_score, l.set2_score, l.set3_score ]) } }
    result = LineScoring.match_result(summary, mode)
    match.update!(result: result) if result
  end

  # One set as "ours-theirs" from the two number boxes (setN_ours /
  # setN_theirs), falling back to a "6-3" text box (setN_score). Keeps the
  # saved text (e.g. "7-6(5)") when the numbers weren't changed.
  def set_string(data, n, saved)
    ours = data["set#{n}_ours"]
    theirs = data["set#{n}_theirs"]
    return data["set#{n}_score"].presence if ours.nil? && theirs.nil?
    ours = ours.to_s.strip
    theirs = theirs.to_s.strip
    return nil if ours.blank? && theirs.blank?
    typed = "#{ours.presence || 0}-#{theirs.presence || 0}"
    saved_nums = saved.to_s.scan(/\d+/).first(2)
    saved.present? && saved_nums == [ ours.presence || "0", theirs.presence || "0" ] ? saved : typed
  end

  # Lines in the team's format. Singles take the first positions, doubles
  # follow (positions are unique per match).
  def build_default_lines(match)
    default_line_types(match).each_with_index do |line_type, i|
      MatchLine.create!(match: match, line_type: line_type, position: i + 1)
    end
  end

  def default_line_types(match)
    plan = match.tennis_team.lineup_slot_plan.keys
    plan.select { |(t, _)| t == "singles" }.map(&:first) + plan.select { |(t, _)| t == "doubles" }.map(&:first)
  end

  def wrong_layout?(match)
    lines = match.match_lines.order(:position).to_a
    lines.any? && lines.map(&:line_type) != default_line_types(match)
  end

  def rebuild_unused_lines(match)
    # Players alone don't count: they're re-filled from the published lineup.
    unused = match.match_lines.none? { |l| l.scored? || l.opponents.present? }
    match.match_lines.destroy_all if unused
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

    # Lines that already had players before we start: those are the
    # captain's choice and stay as they are. (Checking "has players" inside
    # the loop skipped every doubles partner: the first name filled the line.)
    lines_with_players = match.match_lines.joins(:match_line_players).distinct.pluck(:id)

    lineup.lineup_slots.where.not(user_id: nil).find_each do |slot|
      match_line_position =
        if slot.line_type == "singles"
          slot.position
        else
          slot.position + singles_offset
        end

      match_line = match.match_lines.find_by(line_type: slot.line_type, position: match_line_position)
      next unless match_line
      next if lines_with_players.include?(match_line.id) # respect captain's edits
      next if match_line.match_line_players.exists?(user_id: slot.user_id)

      match_line.match_line_players.create!(user_id: slot.user_id)
    end
  end

  def set_team
    @team = TennisTeam.find_by(id: params[:team_id])
    redirect_to teams_path, alert: "Team not found." unless @team
  end

  def require_results_editor
    return if @team.can_enter_results?(current_user)
    redirect_to team_path(@team), alert: "Only the team's captains can enter or change results."
  end

  def require_membership
    return if @team&.team_memberships&.exists?(user: current_user)
    redirect_to teams_path, alert: "You're not a member of this team."
  end

  def require_login
    redirect_to login_path, alert: "Please sign in first." unless current_user
  end

  def match_params
    params.require(:match).permit(:match_date, :match_time, :location, :opponent, :notes, :home_away, :playoff_level)
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
