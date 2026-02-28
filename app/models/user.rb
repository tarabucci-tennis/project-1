class User < ApplicationRecord
  validates :name, presence: true
  validates :email, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP },
                    allow_blank: true

  before_save { self.email = email&.downcase.presence }
end
