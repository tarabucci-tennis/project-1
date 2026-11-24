# A beta-feedback message (Tara, Nov 24 2026). Signed-in players are linked to
# their account; guests on the public pages may leave a name. Only admins read
# them (/admin/feedback).
class Feedback < ApplicationRecord
  belongs_to :user, optional: true

  validates :message, presence: { message: "can't be empty" }, length: { maximum: 2000 }
  validates :name, length: { maximum: 80 }
  validates :page, length: { maximum: 300 }

  def from_label
    return "Anonymous" if anonymous?
    user&.name.presence || name.presence || "Someone not signed in"
  end
end
