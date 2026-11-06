require "rails_helper"

RSpec.describe LoanMailer do
  let(:reader) { create(:reader, full_name: "John Doe", email: "john.doe@example.com") }
  let(:book) { create(:book, title: "Dune", author: "Frank Herbert") }
  let(:loan) { create(:loan, book: book, reader: reader, borrowed_at: Time.zone.local(2026, 10, 1, 12, 0)) }

  describe "#due_soon" do
    subject(:mail) { described_class.with(loan: loan).due_soon }

    it "is sent to the reader with the book and the due date" do
      expect(mail.to).to eq([ "john.doe@example.com" ])
      expect(mail.from).to eq([ "library@example.com" ])
      expect(mail.subject).to eq("Reminder: \"Dune\" is due on 2026-10-31")
      expect(mail.body.encoded).to include("John Doe", "Dune", "Frank Herbert", "2026-10-31",
                                                 "due in #{LoanRemindersJob::DAYS_BEFORE_DUE} days")
    end
  end

  describe "#due_today" do
    subject(:mail) { described_class.with(loan: loan).due_today }

    it "is sent to the reader with the book and the due date" do
      expect(mail.to).to eq([ "john.doe@example.com" ])
      expect(mail.subject).to eq("\"Dune\" is due today")
      expect(mail.body.encoded).to include("John Doe", "Dune", "2026-10-31", "due today")
    end
  end

  context "when the book was returned after the reminder was queued" do
    before { loan.update!(returned_at: Time.current) }

    %i[due_soon due_today].each do |email|
      it "#{email} sends nothing" do
        expect { described_class.with(loan: loan).public_send(email).deliver_now }
          .not_to change(ActionMailer::Base.deliveries, :count)
      end
    end
  end
end
