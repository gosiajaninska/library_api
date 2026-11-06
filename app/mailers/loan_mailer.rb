class LoanMailer < ApplicationMailer
  # LoanMailer.with(loan: loan).due_soon.deliver_later
  before_action { @loan = params[:loan] }

  # deliver_later builds the email when the mail job runs, maybe minutes after
  # LoanRemindersJob queued it. If the book was returned in between, an action
  # that never calls `mail` sends nothing.
  def due_soon
    return unless @loan.active?

    mail to: @loan.reader.email, subject: "Reminder: \"#{@loan.book.title}\" is due on #{@loan.due_on}"
  end

  def due_today
    return unless @loan.active?

    mail to: @loan.reader.email, subject: "\"#{@loan.book.title}\" is due today"
  end
end
