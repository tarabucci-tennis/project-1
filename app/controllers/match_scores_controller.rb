class MatchScoresController < ApplicationController
  before_action :require_login
  before_action :set_team_and_match
  before_action :require_captain

  def new
    @players = @team.team_players.ordered
    @scores = {}
    LineupSlot::POSITIONS.each do |pos|
      existing = @match.match_scores.find_by(position: pos)
      @scores[pos] = existing || @match.match_scores.build(position: pos)
    end
  end

  def create
    save_scores
    redirect_to team_scheduled_match_path(@team, @match), notice: "Scores saved!"
  end

  def edit
    @players = @team.team_players.ordered
    @scores = {}
    LineupSlot::POSITIONS.each do |pos|
      @scores[pos] = @match.match_scores.find_by(position: pos) || @match.match_scores.build(position: pos)
    end
  end

  def update
    save_scores
    redirect_to team_scheduled_match_path(@team, @match), notice: "Scores updated!"
  end

  private

  def require_login
    redirect_to login_path, alert: "Please sign in." unless current_user
  end

  def set_team_and_match
    @team = Team.find(params[:team_id])
    @match = @team.scheduled_matches.find(params[:scheduled_match_id])
  end

  def require_captain
    unless current_user.captain_of?(@team) || current_user.super_admin?
      redirect_to team_path(@team), alert: "Only the captain can enter scores."
    end
  end

  def save_scores
    courts_won = 0
    courts_lost = 0

    params[:scores]&.each do |position, score_data|
      next if score_data[:result].blank?

      score = @match.match_scores.find_or_initialize_by(position: position)
      score.assign_attributes(
        player1_id: score_data[:player1_id].presence,
        player2_id: score_data[:player2_id].presence,
        opponent1_name: score_data[:opponent1_name],
        opponent2_name: score_data[:opponent2_name],
        set1_score: score_data[:set1_score],
        set2_score: score_data[:set2_score],
        set3_score: score_data[:set3_score],
        result: score_data[:result]
      )
      score.save!

      courts_won += 1 if score.win?
      courts_lost += 1 if score.loss?
    end

    team_result = if courts_won + courts_lost > 0
      courts_won > courts_lost ? "win" : "loss"
    end

    @match.update!(team_result: team_result, courts_won: courts_won, courts_lost: courts_lost)
  end
end
