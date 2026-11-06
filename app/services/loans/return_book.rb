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
        loan
      end
    end

    private

    attr_reader :book
  end
end
