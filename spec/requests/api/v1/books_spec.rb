require "rails_helper"

RSpec.describe "Books API", type: :request do
  let(:json) { response.parsed_body }

  describe "GET /api/v1/books" do
    it "lists books with their status, ordered by serial number" do
      create(:book, serial_number: "200002", title: "Available book")
      borrowed = create(:book, serial_number: "200001", title: "Borrowed book")
      loan = create(:loan, book: borrowed)

      get "/api/v1/books"

      expect(response).to have_http_status(:ok)
      expect(json.pluck("serial_number")).to eq(%w[200001 200002])
      expect(json.first).to include("title" => "Borrowed book", "status" => "borrowed")
      expect(json.first["current_loan"]).to include("due_on" => loan.due_on.iso8601)
      expect(json.first.dig("current_loan", "reader", "card_number")).to eq(loan.reader.card_number)
      expect(json.second).to include("title" => "Available book", "status" => "available", "current_loan" => nil)
    end

    it "does not list discarded books" do
      create(:book, :discarded)

      get "/api/v1/books"

      expect(json).to eq([])
    end
  end

  describe "GET /api/v1/books/:serial_number" do
    let(:book) { create(:book) }
    let(:path) { "/api/v1/books/#{book.serial_number}" }

    it "returns the book with its full borrowing history, newest first" do
      old_loan = create(:loan, :returned, book: book)
      current_loan = create(:loan, book: book)

      get path

      expect(response).to have_http_status(:ok)
      expect(json).to include("serial_number" => book.serial_number, "status" => "borrowed")
      expect(json["loans"].map { |loan| loan.dig("reader", "card_number") })
        .to eq([ current_loan.reader.card_number, old_loan.reader.card_number ])
      expect(json["loans"].last.keys).to contain_exactly("borrowed_at", "due_on", "returned_at", "reader")
      expect(json["loans"].last["returned_at"]).to be_present
      expect(json["loans"].last["reader"].keys).to contain_exactly("card_number", "full_name", "email")
    end

    it "returns an empty history for a book that was never borrowed" do
      get path

      expect(json).to include("status" => "available", "loans" => [])
    end

    it "returns 404 for an unknown serial number" do
      get "/api/v1/books/999999"

      expect(response).to have_http_status(:not_found)
      expect(json).to eq("error" => "Book not found")
    end

    it "returns 404 for a discarded book" do
      book.discard!

      get path

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/books" do
    let(:params) { { book: { serial_number: "000123", title: "Dune", author: "Frank Herbert" } } }

    it "creates an available book" do
      expect { post "/api/v1/books", params: params, as: :json }.to change(Book, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json).to include("serial_number" => "000123", "title" => "Dune", "status" => "available")
    end

    it "returns 422 with details for invalid data" do
      post "/api/v1/books", params: { book: { serial_number: "123", title: "", author: "X" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["error"]).to eq("Validation failed")
      expect(json["details"].keys).to contain_exactly("serial_number", "title")
    end

    it "returns 422 when the serial number is taken, also by a discarded book" do
      create(:book, :discarded, serial_number: "000123")

      post "/api/v1/books", params: params, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json.dig("details", "serial_number")).to include("Serial number has already been taken")
    end

    it "returns 400 when the book parameter is missing" do
      post "/api/v1/books", params: {}, as: :json

      expect(response).to have_http_status(:bad_request)
    end
  end

  describe "DELETE /api/v1/books/:serial_number" do
    let(:book) { create(:book) }
    let(:path) { "/api/v1/books/#{book.serial_number}" }

    it "soft deletes the book and keeps its borrowing history" do
      create(:loan, :returned, book: book)

      delete path

      expect(response).to have_http_status(:no_content)
      expect(book.reload).to be_discarded
      expect(book.loans.count).to eq(1)
    end

    it "returns 409 when the book is currently borrowed" do
      create(:loan, book: book)

      delete path

      expect(response).to have_http_status(:conflict)
      expect(json).to eq("error" => "Book is currently borrowed and cannot be removed")
      expect(book.reload).not_to be_discarded
    end

    it "returns 404 when the book is already deleted" do
      book.discard!

      delete path

      expect(response).to have_http_status(:not_found)
    end
  end
end
