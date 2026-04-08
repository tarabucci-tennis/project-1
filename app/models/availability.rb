class Availability < ApplicationRecord
  belongs_to :user
  belongs_to :match

  validates :status, inclusion: { in: %w[in out no_response] }
  validates :user_id, uniqueness: { scope: :match_id }
end
