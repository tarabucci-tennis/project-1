class TennisTeam < ApplicationRecord
  belongs_to :user
  has_many :tennis_matches, dependent: :destroy
end
