module LibraryErrors
  class Conflict < StandardError; end

  class AlreadyBorrowed < Conflict
    def initialize(message = "Book is already borrowed")
      super
    end
  end

  class NotBorrowed < Conflict
    def initialize(message = "Book is not borrowed")
      super
    end
  end

  class BorrowedBookDiscard < Conflict
    def initialize(message = "Book is currently borrowed and cannot be removed")
      super
    end
  end

  class BookDiscarded < Conflict
    def initialize(message = "Book has been removed from the collection")
      super
    end
  end

  class InvalidRequest < StandardError; end

  class ReaderNotFound < InvalidRequest
    def initialize(message = "Reader not found")
      super
    end
  end

  class InvalidStatus < InvalidRequest
    def initialize(message = "Status must be one of: #{Book::STATUSES.join(', ')}")
      super
    end
  end
end
