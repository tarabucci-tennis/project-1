class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :tennis_team
  belongs_to :match
  belongs_to :actor, class_name: "User"

  scope :unread, -> { where(read: false) }
  scope :recent, -> { order(created_at: :desc).limit(20) }
end
