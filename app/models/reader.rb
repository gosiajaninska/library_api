class Reader < ApplicationRecord
  has_many :loans, dependent: :restrict_with_exception

  normalizes :card_number, :full_name, with: ->(value) { value.strip }
  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :card_number, presence: true,
                          uniqueness: true,
                          format: { with: /\A\d{6}\z/, allow_blank: true }
  validates :email, presence: true,
                    uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :full_name, presence: true
end
