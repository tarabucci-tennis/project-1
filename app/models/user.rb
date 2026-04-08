class User < ApplicationRecord
  NOTIFICATION_PREFS = %w[every_update count_only none].freeze

  has_secure_password validations: false

  has_many :tennis_teams, dependent: :destroy
  has_many :tennis_stats, dependent: :destroy
  has_many :captained_teams, class_name: "Team", foreign_key: :captain_id, dependent: :destroy
  has_many :team_players, dependent: :destroy
  has_many :teams, through: :team_players
  has_many :captain_notifications, dependent: :destroy

  validates :name, presence: true
  validates :email, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    allow_blank: true
  validates :password, length: { minimum: 6 }, if: -> { password_digest_changed? || new_record? && password.present? }
  validates :notification_preference, inclusion: { in: NOTIFICATION_PREFS }, allow_nil: true

  before_save { self.email = email&.downcase.presence }

  def captain_of?(team)
    team.captain_id == id
  end

  def super_admin?
    respond_to?(:super_admin) ? super_admin : false
  rescue ActiveRecord::StatementInvalid
    false
  end

  def generate_reset_token!
    update!(
      reset_password_token: SecureRandom.urlsafe_base64(32),
      reset_password_sent_at: Time.current
    )
  end

  def generate_invite_token!
    update!(
      invite_token: SecureRandom.urlsafe_base64(32),
      invited_at: Time.current
    )
  end

  def notify_every_update?
    notification_preference == "every_update"
  end

  def notify_count_only?
    notification_preference == "count_only"
  end

  def notifications_off?
    notification_preference == "none"
  end

  def notification_preference_set?
    notification_preference.present?
  end

  def unread_notifications_count
    captain_notifications.unread.count
  end
end
