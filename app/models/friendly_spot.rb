# One person's claim on a friendly. Signed-in players are linked to their
# account; guests just give a name and get a private key (kept in a cookie)
# so they can take their own name back off.
class FriendlySpot < ApplicationRecord
  belongs_to :friendly
  belongs_to :user, optional: true

  validates :name, presence: true, length: { maximum: 60 }
  validates :user_id, uniqueness: { scope: :friendly_id }, allow_nil: true
  validate :name_not_taken

  private

  def name_not_taken
    return if name.blank?
    taken = FriendlySpot.where(friendly_id: friendly_id).where.not(id: id)
                        .where("LOWER(name) = ?", name.strip.downcase).exists?
    errors.add(:name, "is already on the list") if taken
  end
end
