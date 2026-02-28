class TennisStat < ApplicationRecord
  belongs_to :user
  scope :chronological, -> { order(year: :desc) }

  def match_wpct
    return nil unless matches_total&.positive?
    (matches_won.to_f / matches_total * 100).round(2)
  end

  def set_wpct
    return nil unless sets_total&.positive?
    (sets_won.to_f / sets_total * 100).round(2)
  end

  def game_wpct
    return nil unless games_total&.positive?
    (games_won.to_f / games_total * 100).round(2)
  end
end
