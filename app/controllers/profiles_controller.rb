class ProfilesController < ApplicationController
  before_action :require_login

  # GET /profile — your own profile
  def show
    @user  = current_user
    @teams = current_user.member_teams.includes(:team_memberships).order(start_date: :desc)
    @teams = current_user.tennis_teams.order(start_date: :desc) if @teams.empty?
    @stats = @user.tennis_stats.chronological
    @is_self = true
    @shared_teams = []
    @playing_stats = build_playing_stats(@user)
    render :player
  end

  # GET /players/:id — teammate's profile
  def player
    @user = User.find_by(id: params[:id])
    unless @user
      redirect_to teams_path, alert: "Player not found."
      return
    end

    @teams = @user.member_teams.includes(:team_memberships).order(start_date: :desc)
    @stats = @user.tennis_stats.chronological
    @is_self = (@user.id == current_user.id)

    # Find teams you share with this player
    my_team_ids = current_user.member_teams.pluck(:id)
    their_team_ids = @user.member_teams.pluck(:id)
    shared_ids = my_team_ids & their_team_ids
    @shared_teams = TennisTeam.where(id: shared_ids).order(start_date: :desc)
    @playing_stats = build_playing_stats(@user)
  end

  private

  def require_login
    redirect_to login_path unless current_user
  end

  def build_playing_stats(user)
    lines = MatchLine.joins(:match_line_players)
                     .where(match_line_players: { user_id: user.id })
                     .where.not(result: nil)
                     .includes(match: :tennis_team)

    return nil if lines.empty?

    stats = {}

    # Overall
    total = lines.count
    won = lines.where(result: "win").count
    lost = lines.where(result: "loss").count
    stats[:overall] = { won: won, lost: lost, total: total, pct: pct(won, total) }

    # Singles vs Doubles
    singles = lines.where(line_type: "singles")
    doubles = lines.where(line_type: "doubles")
    s_won = singles.where(result: "win").count
    s_total = singles.count
    d_won = doubles.where(result: "win").count
    d_total = doubles.count
    stats[:singles] = { won: s_won, total: s_total, pct: pct(s_won, s_total) }
    stats[:doubles] = { won: d_won, total: d_total, pct: pct(d_won, d_total) }

    # Win % by line position
    stats[:by_line] = {}
    lines.group_by { |l| l.line_type == "singles" ? "1S" : "#{l.position}D" }.each do |label, group|
      w = group.count { |l| l.result == "win" }
      t = group.size
      stats[:by_line][label] = { won: w, total: t, pct: pct(w, t) }
    end

    # Doubles partner stats
    stats[:partners] = []
    doubles_lines = lines.where(line_type: "doubles").includes(match_line_players: :user)
    partner_data = Hash.new { |h, k| h[k] = { won: 0, lost: 0, total: 0 } }

    doubles_lines.each do |line|
      partners = line.match_line_players.map(&:user).reject { |u| u.id == user.id }
      partners.each do |partner|
        partner_data[partner.name][:total] += 1
        partner_data[partner.name][:won] += 1 if line.result == "win"
        partner_data[partner.name][:lost] += 1 if line.result == "loss"
      end
    end

    stats[:partners] = partner_data.map do |name, data|
      { name: name, won: data[:won], lost: data[:lost], total: data[:total], pct: pct(data[:won], data[:total]) }
    end.sort_by { |p| [-p[:pct], -p[:total]] }

    # Best doubles partner
    stats[:best_partner] = stats[:partners].first if stats[:partners].any?

    # Recent matches (last 5)
    stats[:recent] = lines.sort_by { |l| l.match.match_date }.last(5).reverse.map do |line|
      {
        date: line.match.match_date,
        opponent: line.match.opponent,
        team: line.match.tennis_team.name,
        line_label: line.line_type == "singles" ? "#{line.position}S" : "#{line.position}D",
        result: line.result,
        score: line.score_display
      }
    end

    stats
  end

  def pct(won, total)
    return 0 if total == 0
    (won.to_f / total * 100).round(0)
  end
end
