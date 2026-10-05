# Saves a parsed USTA "Team Summary" (UstaTeamSummaryParser) onto one Court
# Report team. USTA is the authority for these numbers, so they're stored
# exactly as published:
#
#   * our standings row  -> tennis_teams.usta_* (shown instead of anything
#                           Court Report would calculate)
#   * rival rows         -> division_teams (created or updated by name)
#   * team matches       -> each match's team score ("23-0", our points
#                           first), W/L and USTA confirmation status. Missing
#                           matches are added. Line-by-line scores are never
#                           touched — the file doesn't have them.
#   * roster             -> each player's official NTRP; anyone not yet on the
#                           team is added as a player. Nobody is removed.
#
# `plan` describes the changes without saving (for the preview); `apply!`
# saves them in one transaction. Both are safe to run again.
class UstaTeamSummaryImport
  Plan = Struct.new(:our_row, :rivals, :matches_new, :matches_updated,
                    :players_new, :ratings_changed, :warnings, keyword_init: true)

  def initialize(team, parsed)
    @team = team
    @parsed = parsed
  end

  def plan
    our = our_row
    warnings = []
    warnings << "This file's standings don't list \"#{@team.name}\" — check you uploaded this team's file." if our.nil? && @parsed.standings.any?

    new_m = []
    upd_m = []
    @parsed.matches.each do |m|
      existing = find_match(m)
      if existing.nil?
        new_m << m
      elsif m.played? && (existing.score_summary != score_for(m) || existing.usta_status != m.status)
        upd_m << m
      end
    end

    new_p = []
    rating_changes = []
    @parsed.players.each do |p|
      user = find_user(p.name)
      new_p << p.name unless user && member?(user)
      if p.ntrp && user && user.ntrp_rating.to_f != p.ntrp
        rating_changes << "#{p.name}: #{user.ntrp_rating || '—'} → #{p.ntrp}"
      end
    end

    Plan.new(our_row: our, rivals: @parsed.standings - [ our ].compact,
             matches_new: new_m, matches_updated: upd_m,
             players_new: new_p, ratings_changed: rating_changes, warnings: warnings)
  end

  def apply!
    ActiveRecord::Base.transaction do
      save_standings
      save_matches
      save_roster
    end
  end

  private

  def save_standings
    if (our = our_row)
      @team.update!(
        usta_matches_played: our.matches_played, usta_points: our.points,
        usta_sets_won: our.sets_won, usta_sets_lost: our.sets_lost,
        usta_games_won: our.games_won, usta_games_lost: our.games_lost,
        usta_games_won_pct: our.games_won_pct, usta_synced_at: Time.current
      )
    end

    (@parsed.standings - [ our ].compact).each do |s|
      dt = @team.division_teams.detect { |d| normalize(d.name) == normalize(s.name) } ||
           @team.division_teams.new(name: s.name)
      dt.update!(matches_played: s.matches_played, points: s.points,
                 sets_won: s.sets_won, sets_lost: s.sets_lost,
                 games_won: s.games_won, games_lost: s.games_lost,
                 games_won_pct: s.games_won_pct)
    end
  end

  def save_matches
    @parsed.matches.each do |m|
      match = find_match(m) ||
              @team.matches.new(match_date: Time.zone.local(m.date.year, m.date.month, m.date.day, 12, 0),
                                opponent: m.opponent)
      if m.played?
        match.score_summary = score_for(m)
        match.result = m.result
      end
      match.usta_status = m.status if m.status.present?
      match.save!
    end
  end

  def save_roster
    @parsed.players.each do |p|
      user = find_user(p.name) || User.create!(name: p.name)
      user.update!(ntrp_rating: p.ntrp) if p.ntrp && user.ntrp_rating.to_f != p.ntrp
      # Any membership row (even an archived one) blocks a second row for the
      # same team, so only add players with none at all.
      next if @team.team_memberships.exists?(user: user)

      TeamMembership.create!(user: user, tennis_team: @team, role: "player")
    end
  end

  def our_row
    @our_row ||= @parsed.standings.detect { |s| normalize(s.name) == normalize(@team.name) }
  end

  # Same date (and, if the team played twice that day, the same opponent).
  def find_match(m)
    same_day = @team.matches.select { |x| x.match_date.to_date == m.date && x.playoff_level.blank? }
    same_day.detect { |x| normalize(x.opponent) == normalize(m.opponent) } ||
      (same_day.one? ? same_day.first : nil)
  end

  def find_user(name)
    User.where("LOWER(name) = ?", name.to_s.strip.downcase).first
  end

  def member?(user)
    @team.team_memberships.active.exists?(user: user)
  end

  def score_for(m)
    "#{m.our_points}-#{m.their_points}"
  end

  def normalize(str)
    str.to_s.strip.downcase.gsub(/\s+/, " ")
  end
end
