module Api
  module V1
    class BooksController < BaseController
      def index
        books = Book.kept.includes(active_loan: :reader).order(:serial_number)

        render json: books.map { |book| BookSerializer.summary(book) }
      end

      def show
        render json: BookSerializer.detail(find_book)
      end

      def create
        book = Book.create!(book_params)

        render json: BookSerializer.summary(book), status: :created
      end

      # Soft delete: the book disappears from the API, its borrowing history stays.
      def destroy
        find_book.discard!

        head :no_content
      end

      # { "status": "borrowed", "card_number": "123456" } or { "status": "available" }
      def update_status
        book = find_book

        case params.require(:status)
        when "borrowed" then Loans::BorrowBook.call(book: book, reader: find_reader)
        when "available" then Loans::ReturnBook.call(book: book)
        else raise LibraryErrors::InvalidStatus
        end

        render json: BookSerializer.summary(book)
      end

      private

      def find_book
        Book.kept.find_by!(serial_number: params[:serial_number])
      end

      # Unknown card number is 422, not 404: the book in the URL exists.
      def find_reader
        Reader.find_by(card_number: params.require(:card_number).to_s) or raise LibraryErrors::ReaderNotFound
      end

      def book_params
        params.expect(book: %i[serial_number title author])
      end
    end
  end
end
