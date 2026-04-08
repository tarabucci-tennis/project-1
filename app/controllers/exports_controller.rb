class ExportsController < ApplicationController
  before_action :require_super_admin

  def team_data
    team = Team.find(params[:team_id])
    players = team.team_players.ordered
    matches = team.scheduled_matches.chronological

    csv = CSV.generate do |rows|
      rows << ["Court Report - #{team.name} Export"]
      rows << []

      # Roster
      rows << ["ROSTER"]
      rows << %w[Name Email Phone Role NTRP]
      players.each do |p|
        rows << [p.player_name, p.user&.email, p.user&.phone, p.role, p.user&.ntrp_rating]
      end
      rows << []

      # Schedule & Results
      rows << ["SCHEDULE & RESULTS"]
      rows << %w[Date Opponent Home/Away Location Result Courts_Won Courts_Lost]
      matches.each do |m|
        rows << [m.match_date, m.opponent_team, m.home_away, m.location, m.team_result, m.courts_won, m.courts_lost]
      end
      rows << []

      # Scores
      rows << ["MATCH SCORES"]
      rows << %w[Date Opponent Position Player1 Player2 Opp1 Opp2 Set1 Set2 Set3 Result]
      matches.each do |m|
        m.match_scores.each do |s|
          rows << [m.match_date, m.opponent_team, s.position, s.player1&.player_name, s.player2&.player_name, s.opponent1_name, s.opponent2_name, s.set1_score, s.set2_score, s.set3_score, s.result]
        end
      end
      rows << []

      # Availability
      rows << ["AVAILABILITY"]
      header = ["Player"] + matches.map { |m| "#{m.match_date} vs #{m.opponent_team}" }
      rows << header
      players.each do |p|
        row = [p.player_name]
        matches.each do |m|
          avail = m.player_availabilities.find_by(team_player: p)
          row << (avail&.display_status || "—")
        end
        rows << row
      end
    end

    send_data csv, filename: "#{team.name.parameterize}-export-#{Date.current}.csv", type: "text/csv"
  end

  private

  def require_super_admin
    unless current_user&.super_admin?
      redirect_to root_path, alert: "Not authorized."
    end
  end
end
