require "rails_helper"

RSpec.describe MailDeliveryJob do
  let(:loan) { create(:loan) }

  def deliver_reminder
    described_class.perform_now("LoanMailer", "due_today", "deliver_now", params: { loan: loan }, args: [])
  end

  it "is the job behind deliver_later" do
    expect { LoanMailer.with(loan: loan).due_today.deliver_later }.to have_enqueued_job(described_class)
  end

  it "delivers the email" do
    expect { deliver_reminder }.to change(ActionMailer::Base.deliveries, :count).by(1)
  end

  it "retries later when the mail server is unavailable" do
    allow_any_instance_of(Mail::TestMailer).to receive(:deliver!).and_raise(Errno::ECONNREFUSED)

    expect { deliver_reminder }.to have_enqueued_job(described_class)
  end

  it "does not retry a permanent rejection" do
    allow_any_instance_of(Mail::TestMailer).to receive(:deliver!).and_raise(Net::SMTPFatalError, "550 no such user")

    expect { deliver_reminder }.to raise_error(Net::SMTPFatalError)
  end
end
