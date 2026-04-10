class User < ApplicationRecord
  has_secure_password validations: false

  has_many :tennis_teams, dependent: :destroy
  has_many :tennis_stats, dependent: :destroy
  has_many :team_memberships, dependent: :destroy
  has_many :member_teams, through: :team_memberships, source: :tennis_team
  has_many :availabilities, dependent: :destroy

  validates :name, presence: true
  validates :email, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    allow_blank: true
  validates :password, length: { minimum: 6 }, if: -> { password_digest_changed? || new_record_with_password? }

  before_save { self.email = email&.downcase.presence }

  has_many :match_line_players, dependent: :destroy
  has_many :match_lines_played, through: :match_line_players, source: :match_line

  def generate_reset_token!
    update!(
      reset_password_token: SecureRandom.urlsafe_base64(32),
      reset_password_sent_at: Time.current
    )
    reset_password_token
  end

  def reset_token_valid?
    reset_password_token.present? && reset_password_sent_at > 2.hours.ago
  end

  def clear_reset_token!
    update!(reset_password_token: nil, reset_password_sent_at: nil)
  end

  private

  def new_record_with_password?
    new_record? && password.present?
  end

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
    lines = match_lines_played.joins(:match_line).where.not(match_lines: { result: nil })
    won = lines.where(match_lines: { result: "win" }).count
    lost = lines.where(match_lines: { result: "loss" }).count
    { won: won, lost: lost, total: won + lost }
  end
end
