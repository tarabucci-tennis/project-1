class Team < ApplicationRecord
  LEAGUES = %w[USTA CUP Deltri].freeze

  belongs_to :captain, class_name: "User"
  has_many :team_players, dependent: :destroy
  has_many :users, through: :team_players
  has_many :scheduled_matches, dependent: :destroy
  has_many :match_scores, through: :scheduled_matches

  validates :name, presence: true
  validates :league, inclusion: { in: LEAGUES }, allow_nil: true
  validates :join_code, uniqueness: true, allow_nil: true

  before_create :generate_join_code

  scope :by_league, ->(league) { where(league: league) }

  def roster_count
    team_players.count
  end

  def spots_needed
    9 # 1S + 4 doubles lines x 2 players
  end

  def join_url(host:)
    "#{host}/join/#{join_code}"
  end

  def record
    wins = scheduled_matches.where(team_result: "win").count
    losses = scheduled_matches.where(team_result: "loss").count
    { wins: wins, losses: losses }
  end

  private

  def generate_join_code
    self.join_code ||= name.parameterize + "-" + SecureRandom.hex(3)
  end
end
