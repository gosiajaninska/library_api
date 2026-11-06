class Loan < ApplicationRecord
  LOAN_PERIOD = 30.days

  belongs_to :book
  belongs_to :reader

  attr_readonly :book_id, :reader_id, :borrowed_at, :due_on

  scope :active, -> { where(returned_at: nil) }
  scope :returned, -> { where.not(returned_at: nil) }

  before_validation :assign_due_on, on: :create

  validates :borrowed_at, presence: true
  validates :due_on, presence: true
  validates :book_id, uniqueness: { conditions: -> { active }, message: "is already borrowed" },
                      if: :active?
  validate :dates_not_in_future
  validate :returned_at_not_before_borrowed_at
  validate :returned_at_set_only_once, on: :update

  def active?
    returned_at.nil?
  end

  private

  def assign_due_on
    return if borrowed_at.blank?

    self.due_on = borrowed_at.in_time_zone.to_date + LOAN_PERIOD
  end

  def dates_not_in_future
    %i[borrowed_at returned_at].each do |attribute|
      value = public_send(attribute)
      next if value.blank? || value <= Time.current

      errors.add(attribute, :in_future, message: "can't be in the future")
    end
  end

  def returned_at_set_only_once
    return unless returned_at_changed? && returned_at_was.present?

    errors.add(:returned_at, :already_returned, message: "can't be changed once the book is returned")
  end

  def returned_at_not_before_borrowed_at
    return if returned_at.blank? || borrowed_at.blank?

    errors.add(:returned_at, :before_borrowed_at, message: "can't be before borrowed_at") if returned_at < borrowed_at
  end
end
