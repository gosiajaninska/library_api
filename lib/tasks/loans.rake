namespace :loans do
  desc "Send loan reminders for today (normally run daily by Solid Queue, see config/recurring.yml)"
  task send_reminders: :environment do
    LoanRemindersJob.perform_now
  end
end
