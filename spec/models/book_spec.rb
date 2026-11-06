require "rails_helper"

RSpec.describe Book, type: :model do
  subject(:book) { build(:book) }

  invalid_serial_numbers = [
    "12345",                                  # too short
    "1234567",                                # too long
    "12a456",                                 # contains a letter
    "123 456",                                # inner space
    "123\n456",                               # inner newline (guards against ^$ vs \A\z)
    "-12345",                                 # sign
    "\uFF11\uFF12\uFF13\uFF14\uFF15\uFF16"    # full-width digits
  ]

  it "has a valid factory" do
    expect(book).to be_valid
  end

  describe "serial_number" do
    it "is normalized by stripping surrounding whitespace" do
      book.serial_number = " 123456 "

      expect(book.serial_number).to eq("123456")
    end

    it "is required and reports only the blank error" do
      book.serial_number = nil

      expect(book).not_to be_valid
      expect(book.errors.details[:serial_number]).to eq([ { error: :blank } ])
    end

    it "accepts six digits with leading zeros" do
      book.serial_number = "000123"

      expect(book).to be_valid
      expect(book.serial_number).to eq("000123")
    end

    it "must be unique" do
      create(:book, serial_number: "123456")
      book.serial_number = "123456"

      expect(book).not_to be_valid
      expect(book.errors).to be_of_kind(:serial_number, :taken)
    end

    it "must be unique also among discarded books" do
      create(:book, :discarded, serial_number: "123456")
      book.serial_number = "123456"

      expect(book).not_to be_valid
      expect(book.errors).to be_of_kind(:serial_number, :taken)
    end

    context "with an invalid format" do
      invalid_serial_numbers.each do |value|
        it "rejects #{value.inspect}" do
          book.serial_number = value

          expect(book).not_to be_valid
          expect(book.errors).to be_of_kind(:serial_number, :invalid)
        end
      end
    end
  end

  %i[title author].each do |attribute|
    describe attribute.to_s do
      it "is normalized by stripping surrounding whitespace" do
        book[attribute] = "  Dune  "

        expect(book[attribute]).to eq("Dune")
      end

      it "is required" do
        book[attribute] = nil

        expect(book).not_to be_valid
        expect(book.errors).to be_of_kind(attribute, :blank)
      end
    end
  end

  describe "soft delete" do
    let!(:kept_book) { create(:book) }
    let!(:discarded_book) { create(:book, :discarded) }

    describe ".kept" do
      it "returns only books that are not discarded" do
        expect(described_class.kept).to contain_exactly(kept_book)
      end
    end

    describe ".discarded" do
      it "returns only discarded books" do
        expect(described_class.discarded).to contain_exactly(discarded_book)
      end
    end

    describe "#discarded?" do
      it "is false for an active book" do
        expect(kept_book).not_to be_discarded
      end

      it "is true for a discarded book" do
        expect(discarded_book).to be_discarded
      end
    end

    describe "#discard!" do
      it "sets discarded_at to the current time and persists it" do
        freeze_time do
          kept_book.discard!

          expect(kept_book.reload.discarded_at).to eq(Time.current)
        end
      end

      it "keeps the original timestamp when called again" do
        kept_book.discard!
        original = kept_book.reload.discarded_at

        travel(1.day) { kept_book.discard! }

        expect(kept_book.reload.discarded_at).to eq(original)
      end

      it "raises and keeps the book when it is currently borrowed" do
        create(:loan, book: kept_book)

        expect { kept_book.discard! }.to raise_error(LibraryErrors::BorrowedBookDiscard)
        expect(kept_book.reload).not_to be_discarded
      end

      it "discards a book that was borrowed and returned, keeping its history" do
        loan = create(:loan, :returned, book: kept_book)

        kept_book.discard!

        expect(kept_book.reload).to be_discarded
        expect(kept_book.loans).to contain_exactly(loan)
      end
    end
  end

  describe "#borrowed?" do
    let(:persisted_book) { create(:book) }

    it "is false without any loans" do
      expect(persisted_book).not_to be_borrowed
    end

    it "is false when all loans have been returned" do
      create(:loan, :returned, book: persisted_book)

      expect(persisted_book).not_to be_borrowed
    end

    it "is true with an active loan" do
      create(:loan, book: persisted_book)

      expect(persisted_book).to be_borrowed
    end
  end

  describe "#destroy" do
    it "is not allowed when the book has loans (history must be kept)" do
      loan = create(:loan, :returned)

      expect { loan.book.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    end
  end

  describe "database constraints" do
    context "unique indexes" do
      it "enforces serial_number uniqueness" do
        create(:book, serial_number: "123456")
        record = build(:book, serial_number: "123456")

        expect { record.save!(validate: false) }
          .to raise_error(ActiveRecord::RecordNotUnique, /index_books_on_serial_number/)
      end
    end

    context "check constraints" do
      invalid_serial_numbers.each do |value|
        it "rejects #{value.inspect} at the database level" do
          record = build(:book, serial_number: value)

          expect { record.save!(validate: false) }
            .to raise_error(ActiveRecord::CheckViolation, /books_serial_number_format/)
        end
      end

      it "enforces not blank on serial_number via the format constraint" do
        record = build(:book, serial_number: "   ")

        expect { record.save!(validate: false) }
          .to raise_error(ActiveRecord::CheckViolation, /books_serial_number_format/)
      end

      %i[title author].each do |attribute|
        it "enforces not blank on #{attribute}" do
          record = build(:book, attribute => "   ")

          expect { record.save!(validate: false) }
            .to raise_error(ActiveRecord::CheckViolation, /books_#{attribute}_not_blank/)
        end
      end
    end

    context "NOT NULL constraints" do
      %i[serial_number title author].each do |attribute|
        it "enforces NOT NULL on #{attribute}" do
          record = build(:book, attribute => nil)

          expect { record.save!(validate: false) }
            .to raise_error(ActiveRecord::NotNullViolation, /"#{attribute}"/)
        end
      end
    end
  end
end
