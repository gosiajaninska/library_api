require "net/smtp"

# Runs every deliver_later (set in ApplicationMailer). Rails' default delivery
# job never retries, so a mail server that is briefly down at 8am would lose
# that day's reminders for good: the next daily sweep no longer matches the loan.
#
# Retries only errors that can succeed later. A permanent rejection
# (Net::SMTPFatalError, e.g. unknown address) fails at once. Retries end
# within about an hour, so "due today" is still true when the email arrives.
class MailDeliveryJob < ActionMailer::MailDeliveryJob
  retry_on Net::OpenTimeout, Net::ReadTimeout, Net::SMTPServerBusy,
           Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, SocketError,
           wait: 10.minutes, attempts: 6
end
