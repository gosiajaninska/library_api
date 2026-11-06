class Book < ApplicationRecord
  STATUSES = %w[borrowed available].freeze

  has_many :loans, dependent: :restrict_with_exception
  has_one :active_loan, -> { active }, class_name: "Loan", inverse_of: :book

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

  def borrowed?
    active_loan.present?
  end

  def status
    borrowed? ? "borrowed" : "available"
  end

  def discard!
    with_lock do
      raise LibraryErrors::BorrowedBookDiscard if borrowed?

      touch(:discarded_at) unless discarded?
    end
    true
  end
end
