class PlayerMatch < ApplicationRecord
  belongs_to :user

  scope :chronological, -> { order(Arel.sql("played_on DESC NULLS LAST"), created_at: :desc) }

  def won?
    result == "win"
  end

  def result_label
    won? ? "W" : "L"
  end
end
