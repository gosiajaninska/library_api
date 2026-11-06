class Book < ApplicationRecord
  normalizes :serial_number, :title, :author, with: ->(value) { value.strip }

  validates :serial_number, presence: true,
                            uniqueness: true,
                            format: { with: /\A\d{6}\z/, allow_blank: true }
  validates :title, presence: true
  validates :author, presence: true

  scope :kept, -> { where(discarded_at: nil) }
  scope :discarded, -> { where.not(discarded_at: nil) }

  def discarded?
    discarded_at.present?
  end

  def discard!
    return true if discarded?

    touch(:discarded_at)
  end
end
