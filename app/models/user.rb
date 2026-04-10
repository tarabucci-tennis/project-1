class User < ApplicationRecord
  has_many :tennis_teams, dependent: :destroy
  has_many :tennis_stats, dependent: :destroy
  has_many :team_memberships, dependent: :destroy
  has_many :member_teams, through: :team_memberships, source: :tennis_team
  has_many :availabilities, dependent: :destroy

  validates :name, presence: true
  validates :email, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    allow_blank: true

  before_save { self.email = email&.downcase.presence }

  has_many :match_line_players, dependent: :destroy
  has_many :match_lines_played, through: :match_line_players, source: :match_line

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
