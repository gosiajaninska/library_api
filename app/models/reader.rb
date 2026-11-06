class Reader < ApplicationRecord
  normalizes :card_number, with: ->(card_number) { card_number.strip }
  normalizes :email, with: ->(email) { email.strip.downcase }
  normalizes :full_name, with: ->(full_name) { full_name.strip }

  validates :card_number, presence: true,
                          uniqueness: true,
                          format: { with: /\A\d{6}\z/, allow_blank: true }
  validates :email, presence: true,
                    uniqueness: true,
                    format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validates :full_name, presence: true
end
