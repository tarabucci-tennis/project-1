class TennisMatch < ApplicationRecord
  belongs_to :tennis_team

  scope :chronological, -> { order(match_date: :desc) }
end
