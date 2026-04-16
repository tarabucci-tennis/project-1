class Lineup < ApplicationRecord
  belongs_to :match
  has_many :lineup_slots, dependent: :destroy

  def published?
    published && published_at.present?
  end

  def all_confirmed?
    lineup_slots.any? && lineup_slots.all? { |s| s.confirmation == "confirmed" }
  end

  def confirmed_count
    lineup_slots.where(confirmation: "confirmed").count
  end

  def pending_count
    lineup_slots.where(confirmation: "pending").count
  end

  def declined_count
    lineup_slots.where(confirmation: "declined").count
  end

  def slot_for(user)
    lineup_slots.find_by(user: user)
  end
end
