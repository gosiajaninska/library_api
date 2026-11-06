require "rails_helper"

RSpec.describe Loans::BorrowBook do
  let(:book) { create(:book) }
  let(:reader) { create(:reader) }

  it "creates an active loan for the reader, due in 30 days" do
    freeze_time do
      loan = described_class.call(book: book, reader: reader)

      expect(loan).to be_persisted
      expect(loan).to have_attributes(book: book, reader: reader, returned_at: nil,
                                      borrowed_at: Time.current, due_on: Date.current + 30)
    end
  end

  it "allows borrowing a book again after it was returned" do
    create(:loan, :returned, book: book)

    expect { described_class.call(book: book, reader: reader) }.to change(book.loans, :count).by(1)
  end

  it "raises when the book is already borrowed" do
    create(:loan, book: book)

    expect { described_class.call(book: book, reader: reader) }
      .to raise_error(LibraryErrors::AlreadyBorrowed)
    expect(book.loans.active.count).to eq(1)
  end

  it "sees a loan made elsewhere, even when the book's active loan was already cached" do
    expect(book).not_to be_borrowed # caches active_loan as nil
    create(:loan, book: Book.find(book.id)) # e.g. another request

    expect { described_class.call(book: book, reader: reader) }
      .to raise_error(LibraryErrors::AlreadyBorrowed)
    expect(book.loans.active.count).to eq(1)
  end

  it "raises BookDiscarded when the book has been discarded" do
    book.discard!

    expect { described_class.call(book: book, reader: reader) }.to raise_error(LibraryErrors::BookDiscarded)
  end

  it "sees a discard made elsewhere, even when holding a stale book object" do
    Book.find(book.id).discard! # e.g. another request

    expect { described_class.call(book: book, reader: reader) }.to raise_error(LibraryErrors::BookDiscarded)
    expect(book.loans).to be_empty
  end
end
