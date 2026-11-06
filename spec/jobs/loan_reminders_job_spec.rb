require "rails_helper"

RSpec.describe LoanRemindersJob do
  let(:today) { Date.new(2026, 11, 20) }

  def loan_due_on(date, **attributes)
    create(:loan, borrowed_at: (date - Loan::LOAN_PERIOD).in_time_zone.change(hour: 12), **attributes)
  end

  around { |example| travel_to(today.in_time_zone.change(hour: 8)) { example.run } }

  it "sends a reminder 3 days before the due date" do
    loan = loan_due_on(today + 3)

    expect { described_class.perform_now }
      .to have_enqueued_mail(LoanMailer, :due_soon).with(params: { loan: loan }, args: [])
  end

  it "sends a reminder on the due date" do
    loan = loan_due_on(today)

    expect { described_class.perform_now }
      .to have_enqueued_mail(LoanMailer, :due_today).with(params: { loan: loan }, args: [])
  end

  it "sends nothing for loans due on other days" do
    [ today - 1, today + 1, today + 2, today + 4 ].each { |date| loan_due_on(date) }

    expect { described_class.perform_now }.not_to have_enqueued_mail
  end

  it "sends nothing for returned books" do
    loan_due_on(today, returned_at: today.in_time_zone - 1.day)
    loan_due_on(today + 3, returned_at: today.in_time_zone - 1.day)

    expect { described_class.perform_now }.not_to have_enqueued_mail
  end
end
