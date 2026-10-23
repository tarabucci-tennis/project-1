class User < ApplicationRecord
  # Court Report's own rating is hidden everywhere until it's rebuilt (Tara,
  # Oct 2026): it scored every line at the team's level and ignored opponents'
  # ratings, so e.g. a 3.0 on a Tri-Level 3.0 line could outrank a 4.0 who
  # plays line 1. Players see only their official USTA (NTRP) rating. The
  # number is still computed in the background; flip this to bring it back.
  SHOW_COURT_REPORT_RATING = false
  # has_secure_password with validations: false so existing users without a
  # password_digest can still be saved. New users created via /signup get
  # their password validated by an explicit check in RegistrationsController.
  has_secure_password validations: false

  has_many :tennis_teams, dependent: :destroy
  has_many :tennis_stats, dependent: :destroy
  has_many :team_memberships, dependent: :destroy
  has_many :member_teams, through: :team_memberships, source: :tennis_team
  has_many :availabilities, dependent: :destroy
  has_many :organized_friendlies, class_name: "Friendly", foreign_key: :organizer_id, dependent: :destroy
  has_many :friendly_spots, dependent: :nullify

  validates :name, presence: true
  validates :email, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    allow_blank: true

  before_save { self.email = email&.downcase.presence }

  # True if the user has set a password. Existing users (seeded without one)
  # can still sign in with just email until they set one, then password is
  # required going forward.
  def password_set?
    password_digest.present?
  end

  # ── Member activity (admin-only Site members page) ──────────────────────
  # Days are counted on Eastern time. Writes skip validations/callbacks and
  # leave updated_at alone, and happen at most once per day per person.
  ACTIVITY_ZONE = "Eastern Time (US & Canada)".freeze

  # People who actually made an account (roster-only placeholders have no
  # password and have never signed in).
  scope :registered, -> { where.not(password_digest: [ nil, "" ]).or(where("sign_in_count > 0")) }

  def record_sign_in!
    now = Time.current
    update_columns(sign_in_count: sign_in_count + 1, last_sign_in_at: now)
    record_visit!(now)
  end

  # Counts one visit per day the person opens any page while signed in.
  def record_visit!(now = Time.current)
    today = now.in_time_zone(ACTIVITY_ZONE).to_date
    return if last_seen_on == today
    update_columns(days_visited: days_visited + 1, last_seen_on: today, last_seen_at: now)
  end

  # Generate a short-lived password reset token. Token is URL-safe and stored
  # in the DB; we compare against params[:token] in the reset flow. Returns
  # the plaintext token (so the controller can build the reset link).
  def generate_reset_token!
    token = SecureRandom.urlsafe_base64(32)
    update!(reset_password_token: token, reset_password_sent_at: Time.current)
    token
  end

  # True if a reset token was issued within the last 2 hours.
  def reset_token_valid?
    reset_password_sent_at.present? && reset_password_sent_at > 2.hours.ago
  end

  def clear_reset_token!
    update!(reset_password_token: nil, reset_password_sent_at: nil)
  end

  has_many :match_line_players, dependent: :destroy
  has_many :match_lines_played, through: :match_line_players, source: :match_line
  has_many :player_matches, dependent: :destroy

  # Get all matches where this player was assigned to a line
  def matches_played
    Match.joins(match_lines: :match_line_players)
         .where(match_line_players: { user_id: id })
         .distinct
  end

  # Live match stats calculated from actual results (not seeded tennis_stats)
  def live_match_count
    matches_played.where.not(result: nil).count
  end

  def live_line_record
    # match_lines_played is already the match_lines table (has_many :through
    # match_line_players), so there's nothing to join — the old .joins(:match_line)
    # referenced a non-existent association and raised.
    lines = match_lines_played.where.not(match_lines: { result: nil })
    won = lines.where(match_lines: { result: "win" }).count
    lost = lines.where(match_lines: { result: "loss" }).count
    { won: won, lost: lost, total: won + lost }
  end
end
