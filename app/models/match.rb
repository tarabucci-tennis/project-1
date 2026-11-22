class Match < ApplicationRecord
  belongs_to :tennis_team
  has_many :availabilities, dependent: :destroy
  has_many :match_lines, -> { order(position: :asc) }, dependent: :destroy
  has_many :match_line_players, through: :match_lines
  has_one :lineup, dependent: :destroy

  validates :match_date, presence: true
  # Official scorecard link (TennisLink, Tenniscores…): web links only.
  validates :scorecard_url, format: { with: %r{\Ahttps?://\S+\z}i, message: "must be a web link (https://…)" }, allow_blank: true
  normalizes :scorecard_url, with: ->(url) { url.strip.presence }

  scope :upcoming, -> { where("match_date >= ?", Time.current).order(match_date: :asc) }
  scope :past, -> { where("match_date < ?", Time.current).order(match_date: :desc) }
  scope :chronological, -> { order(match_date: :asc) }
  scope :completed, -> { where.not(result: nil) }

  # The code in this match's "Can you play?" link (/a/:token), made the first
  # time a captain shares it.
  def availability_token!
    return availability_token if availability_token.present?
    update_column(:availability_token, SecureRandom.urlsafe_base64(9))
    availability_token
  end

  def availability_for(user)
    availabilities.find_by(user: user)
  end

  def availability_counts
    in_count = availabilities.where(status: "in").count
    out_count = availabilities.where(status: "out").count
    total_members = tennis_team.team_memberships.count
    no_response = total_members - in_count - out_count
    { in: in_count, out: out_count, no_response: no_response }
  end

  # The match time as "9:00 AM", however it was typed or imported
  # ("01:30 pm", "10:30am"); nil if none. One format everywhere.
  def time_label
    LineStartTime.normalize(match_time)
  end

  def played?
    result.present?
  end

  # Real scores saved (a line with set scores or W/L, or a team result)?
  # Opening Enter Results creates blank lines, so "has lines" isn't enough.
  def scores_entered?
    result.present? || match_lines.any?(&:scored?)
  end

  # "Enter scores" until something is saved, then "Edit scores".
  def scores_button_label
    scores_entered? ? "Edit scores" : "Enter scores"
  end

  # Is `user` on a line of this match (saved scores or the posted lineup)?
  def on_a_line?(user)
    return false unless user
    match_line_players.exists?(user_id: user.id) ||
      (lineup&.published? && lineup.lineup_slots.exists?(user_id: user.id)) || false
  end

  # The match day has arrived (scores can be entered).
  def started?
    match_date.present? && match_date.to_date <= Date.current
  end

  # Captains can now set home_away directly via the Edit Match form.
  # For older rows where the column is blank, fall back to the legacy
  # heuristic: "Home"/"Away" in notes, or a location that matches the
  # team's home court.
  def home?
    return home_away == "home" if home_away.present?
    return true if notes.to_s.include?("Home")
    home_slug = tennis_team.home_court.to_s.split(",").first.to_s.strip
    home_slug.present? && location.to_s.include?(home_slug)
  end

  def away?
    return home_away == "away" if home_away.present?
    return true if notes.to_s.include?("Away")
    false
  end

  # Bux-Mont / Del-Tri: the club where this match is played, with its
  # address (see ClubDirectory). The listed site wins (Del-Tri sometimes
  # plays at a third club); otherwise it's our club for a home match and the
  # opponent's club for an away one. nil for other leagues or unknown sites.
  def venue
    return @venue if defined?(@venue)
    @venue = find_venue
  end

  def find_venue
    league = tennis_team&.league_label
    return nil unless ClubDirectory.leagues.include?(league)

    if location.present?
      ClubDirectory.find(location, league: league)
    elsif home?
      ClubDirectory.find(tennis_team.home_court, league: league) || ClubDirectory.find(tennis_team.name, league: league)
    elsif away?
      ClubDirectory.find(opponent, league: league)
    end
  end

  def won?
    result == "win"
  end

  def lost?
    result == "loss"
  end

  def tied?
    result == "tie"
  end

  # Does this match belong to a playoff stage (Districts / Sectionals / Nationals)?
  def playoff?
    playoff_level.present?
  end

  # A playoff stage, or a calendar entry turned into a match whose opponent
  # or notes say "Playoffs" — shown with the PLAYOFFS pill.
  def playoff_like?
    playoff? || "#{opponent} #{notes}".match?(/playoff/i)
  end

  # Finished: final scores are in, or its end time has passed. Lineup actions
  # (Set lineup, Ask who can play) hide once a match is finished; any lineup
  # fix after that happens through score entry.
  def finished?
    played? || scores_entered? || over?
  end

  # Over once its end time has passed on the players' (Eastern) clock: the end
  # of a typed range, else the start plus two hours.
  def over?
    return false if match_date.blank?
    text = match_time.presence || (match_date.strftime("%-l:%M %p") unless match_date.hour.zero? && match_date.min.zero?)
    PlayClock.over?(match_date.to_date, text)
  end

  def result_label
    return nil unless played?
    return "T" if tied?
    won? ? "W" : "L"
  end

  def lines_won
    match_lines.where(result: "win").count
  end

  def lines_lost
    match_lines.where(result: "loss").count
  end

  # Did a specific player play in this match?
  def player_played?(user)
    match_line_players.exists?(user: user)
  end
end
