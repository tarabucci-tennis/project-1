class User < ApplicationRecord
  has_many :tennis_teams, dependent: :destroy
  has_many :tennis_stats, dependent: :destroy
  has_many :captained_teams, class_name: "Team", foreign_key: :captain_id, dependent: :destroy
  has_many :team_players, dependent: :destroy

  validates :name, presence: true
  validates :email, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    allow_blank: true

  before_save { self.email = email&.downcase.presence }
end
