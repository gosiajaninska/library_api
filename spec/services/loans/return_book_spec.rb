require "rails_helper"

RSpec.describe Loans::ReturnBook do
  let(:book) { create(:book) }

  it "marks the active loan as returned now" do
    # Borrowed earlier: freeze_time drops sub-second precision, so "now" could
    # otherwise land a few microseconds before borrowed_at.
    loan = create(:loan, book: book, borrowed_at: 1.hour.ago)

    freeze_time do
      expect(described_class.call(book: book)).to eq(loan)
      expect(loan.reload.returned_at).to eq(Time.current)
    end
  end

  it "leaves the book object showing it as available" do
    create(:loan, book: book, borrowed_at: 1.hour.ago)
    expect(book).to be_borrowed # caches the active loan

    described_class.call(book: book)

    expect(book).not_to be_borrowed
  end

  it "does not touch earlier, already returned loans" do
    old_loan = create(:loan, :returned, book: book)
    create(:loan, book: book)

    expect { described_class.call(book: book) }.not_to(change { old_loan.reload.returned_at })
  end

  it "raises when the book is not borrowed" do
    create(:loan, :returned, book: book)

    expect { described_class.call(book: book) }.to raise_error(LibraryErrors::NotBorrowed)
  end
end
