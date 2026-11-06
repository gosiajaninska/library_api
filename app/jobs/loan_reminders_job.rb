# Runs once a day (config/recurring.yml) and emails readers whose active loans
# are due in 3 days or today. A daily sweep instead of jobs scheduled at borrow
# time: a book returned early needs no cancelling, the query just skips it.
class LoanRemindersJob < ApplicationJob
  DAYS_BEFORE_DUE = 3

  def perform
    today = Date.current
    remind(due_on: today + DAYS_BEFORE_DUE, email: :due_soon)
    remind(due_on: today, email: :due_today)
  end

  private

  def remind(due_on:, email:)
    Loan.active.where(due_on: due_on).find_each do |loan|
      LoanMailer.with(loan: loan).public_send(email).deliver_later
    end
  end
end
