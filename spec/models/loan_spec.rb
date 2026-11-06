require "rails_helper"

RSpec.describe Loan, type: :model do
  # "Now" is frozen after every fixed date used below, so the "not in the future"
  # validations do not depend on the day the suite is run.
  around { |example| travel_to(Time.zone.local(2026, 12, 31, 12, 0)) { example.run } }

  subject(:loan) { build(:loan) }

  it "has a valid factory" do
    expect(loan).to be_valid
  end

  describe "required attributes" do
    it "requires a book" do
      loan.book = nil

      expect(loan).not_to be_valid
      expect(loan.errors).to be_of_kind(:book, :blank)
    end

    it "requires a reader" do
      loan.reader = nil

      expect(loan).not_to be_valid
      expect(loan.errors).to be_of_kind(:reader, :blank)
    end

    it "requires borrowed_at" do
      loan.borrowed_at = nil

      expect(loan).not_to be_valid
      expect(loan.errors).to be_of_kind(:borrowed_at, :blank)
    end
  end

  describe "borrowed_at" do
    it "accepts the current time" do
      loan.borrowed_at = Time.current

      expect(loan).to be_valid
    end

    it "rejects a time in the future" do
      loan.borrowed_at = 1.second.from_now

      expect(loan).not_to be_valid
      expect(loan.errors).to be_of_kind(:borrowed_at, :in_future)
    end
  end

  describe "due_on" do
    it "is set to 30 days after borrowed_at on create" do
      loan.borrowed_at = Time.zone.local(2026, 11, 6, 12, 0)
      loan.save!

      expect(loan.due_on).to eq(Date.new(2026, 12, 6))
    end

    it "uses the calendar day in the library time zone, not in UTC" do
      Time.use_zone("Warsaw") do
        loan.borrowed_at = Time.zone.local(2026, 11, 7, 0, 30)
        loan.save!

        expect(loan.due_on).to eq(Date.new(2026, 12, 7))
      end
    end
  end

  describe "returned_at" do
    it "can be equal to borrowed_at" do
      loan.returned_at = loan.borrowed_at

      expect(loan).to be_valid
    end

    it "cannot be before borrowed_at" do
      loan.returned_at = loan.borrowed_at - 1.second

      expect(loan).not_to be_valid
      expect(loan.errors).to be_of_kind(:returned_at, :before_borrowed_at)
    end

    it "rejects a time in the future" do
      loan.returned_at = 1.second.from_now

      expect(loan).not_to be_valid
      expect(loan.errors).to be_of_kind(:returned_at, :in_future)
    end

    it "can be set on an active loan" do
      active_loan = create(:loan)

      active_loan.update!(returned_at: Time.current)

      expect(active_loan.reload).not_to be_active
    end

    context "when the loan has already been returned" do
      let(:returned_loan) { create(:loan, :returned) }

      it "cannot be changed" do
        returned_loan.returned_at = 1.day.ago

        expect(returned_loan).not_to be_valid
        expect(returned_loan.errors).to be_of_kind(:returned_at, :already_returned)
      end

      it "cannot be cleared (un-returning the book)" do
        returned_loan.returned_at = nil

        expect(returned_loan).not_to be_valid
        expect(returned_loan.errors).to be_of_kind(:returned_at, :already_returned)
      end
    end
  end

  describe "read-only attributes" do
    let(:persisted_loan) { create(:loan) }

    {
      book_id: -> { create(:book).id },
      reader_id: -> { create(:reader).id },
      borrowed_at: -> { 1.day.ago },
      due_on: -> { Date.new(2027, 1, 31) }
    }.each do |attribute, new_value|
      it "does not allow changing #{attribute} after creation" do
        expect { persisted_loan.public_send("#{attribute}=", instance_exec(&new_value)) }
          .to raise_error(ActiveRecord::ReadonlyAttributeError)
      end
    end
  end

  describe "#active?" do
    it "is true when the book has not been returned" do
      expect(loan).to be_active
    end

    it "is false when the book has been returned" do
      expect(build(:loan, :returned)).not_to be_active
    end
  end

  describe "scopes" do
    let!(:active_loan) { create(:loan) }
    let!(:returned_loan) { create(:loan, :returned) }

    it ".active returns only loans that have not been returned" do
      expect(described_class.active).to contain_exactly(active_loan)
    end

    it ".returned returns only returned loans" do
      expect(described_class.returned).to contain_exactly(returned_loan)
    end
  end

  describe "one active loan per book" do
    let(:book) { create(:book) }

    it "rejects a second active loan for the same book" do
      create(:loan, book: book)
      second = build(:loan, book: book)

      expect(second).not_to be_valid
      expect(second.errors).to be_of_kind(:book_id, :taken)
    end

    it "allows a new loan after the previous one was returned" do
      create(:loan, :returned, book: book)

      expect(build(:loan, book: book)).to be_valid
    end

    it "allows many returned loans for the same book (history)" do
      create(:loan, :returned, book: book)

      expect(build(:loan, :returned, book: book)).to be_valid
    end
  end

  describe "database constraints" do
    # save!(validate: false) also skips before_validation, so due_on is not calculated
    # and has to be given explicitly unless the test is about due_on itself.

    context "unique indexes" do
      let(:book) { create(:book) }

      it "rejects a second active loan for the same book" do
        create(:loan, book: book)
        record = build(:loan, book: book, due_on: Date.current + 30)

        expect { record.save!(validate: false) }
          .to raise_error(ActiveRecord::RecordNotUnique, /index_loans_on_book_id_active/)
      end

      it "allows an active loan next to returned ones (partial index)" do
        create_list(:loan, 2, :returned, book: book)
        record = build(:loan, book: book, due_on: Date.current + 30)

        expect { record.save!(validate: false) }.not_to raise_error
      end
    end

    context "check constraints" do
      it "rejects returned_at before borrowed_at" do
        record = build(:loan, due_on: Date.current + 30)
        record.returned_at = record.borrowed_at - 1.second

        expect { record.save!(validate: false) }
          .to raise_error(ActiveRecord::CheckViolation, /loans_returned_after_borrowed/)
      end
    end

    context "NOT NULL constraints" do
      it "enforces NOT NULL on book_id" do
        record = build(:loan, book: nil, due_on: Date.current + 30)

        expect { record.save!(validate: false) }
          .to raise_error(ActiveRecord::NotNullViolation, /"book_id"/)
      end

      it "enforces NOT NULL on reader_id" do
        record = build(:loan, reader: nil, due_on: Date.current + 30)

        expect { record.save!(validate: false) }
          .to raise_error(ActiveRecord::NotNullViolation, /"reader_id"/)
      end

      it "enforces NOT NULL on borrowed_at" do
        record = build(:loan, borrowed_at: nil, due_on: Date.current + 30)

        expect { record.save!(validate: false) }
          .to raise_error(ActiveRecord::NotNullViolation, /"borrowed_at"/)
      end

      it "enforces NOT NULL on due_on" do
        record = build(:loan, due_on: nil)

        expect { record.save!(validate: false) }
          .to raise_error(ActiveRecord::NotNullViolation, /"due_on"/)
      end
    end

    context "foreign keys" do
      let!(:existing_loan) { create(:loan) }

      it "prevents hard-deleting a book that has loans" do
        expect { existing_loan.book.delete }.to raise_error(ActiveRecord::InvalidForeignKey)
      end

      it "prevents hard-deleting a reader who has loans" do
        expect { existing_loan.reader.delete }.to raise_error(ActiveRecord::InvalidForeignKey)
      end
    end
  end
end
