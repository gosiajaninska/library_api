module Loans
  class BorrowBook
    def self.call(book:, reader:)
      new(book: book, reader: reader).call
    end

    def initialize(book:, reader:)
      @book = book
      @reader = reader
    end

    def call
      book.with_lock do
        raise LibraryErrors::BookDiscarded if book.discarded?
        raise LibraryErrors::AlreadyBorrowed if book.borrowed?

        book.loans.create!(reader: reader, borrowed_at: Time.current)
      end
    end

    private

    attr_reader :book, :reader
  end
end
