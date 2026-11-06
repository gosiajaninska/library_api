module Loans
  class ReturnBook
    def self.call(book:)
      new(book: book).call
    end

    def initialize(book:)
      @book = book
    end

    def call
      book.with_lock do
        loan = book.active_loan
        raise LibraryErrors::NotBorrowed unless loan

        loan.update!(returned_at: Time.current)
        book.reset_active_loan # the cache still holds the returned loan
        loan
      end
    end

    private

    attr_reader :book
  end
end
