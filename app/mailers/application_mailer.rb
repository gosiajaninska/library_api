class ApplicationMailer < ActionMailer::Base
  default from: "library@example.com"
  layout "mailer"

  # Retries transient SMTP failures, see MailDeliveryJob.
  self.delivery_job = MailDeliveryJob
end
