require "rails_helper"

RSpec.describe "PATCH /api/v1/books/:serial_number/status", type: :request do
  let(:json) { response.parsed_body }
  let(:book) { create(:book) }
  let(:reader) { create(:reader) }
  let(:path) { "/api/v1/books/#{book.serial_number}/status" }

  context "with status: borrowed" do
    it "borrows the book for the reader for 30 days" do
      freeze_time do
        patch path, params: { status: "borrowed", card_number: reader.card_number }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json["status"]).to eq("borrowed")
        expect(json["current_loan"]).to include("due_on" => (Date.current + 30).iso8601)
        expect(json.dig("current_loan", "reader", "card_number")).to eq(reader.card_number)
      end
    end

    it "returns 409 when the book is already borrowed" do
      create(:loan, book: book)

      patch path, params: { status: "borrowed", card_number: reader.card_number }, as: :json

      expect(response).to have_http_status(:conflict)
      expect(json).to eq("error" => "Book is already borrowed")
      expect(book.loans.active.count).to eq(1)
    end

    it "returns 422 when the reader does not exist" do
      patch path, params: { status: "borrowed", card_number: "999999" }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json).to eq("error" => "Reader not found")
      expect(book.loans).to be_empty
    end

    it "returns 400 when card_number is missing" do
      patch path, params: { status: "borrowed" }, as: :json

      expect(response).to have_http_status(:bad_request)
    end

    it "returns 404 for a discarded book" do
      book.discard!

      patch path, params: { status: "borrowed", card_number: reader.card_number }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  context "with status: available" do
    it "returns the book" do
      loan = create(:loan, book: book, borrowed_at: 1.hour.ago)

      patch path, params: { status: "available" }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json).to include("status" => "available", "current_loan" => nil)
      expect(loan.reload).not_to be_active
    end

    it "returns 409 when the book is not borrowed" do
      patch path, params: { status: "available" }, as: :json

      expect(response).to have_http_status(:conflict)
      expect(json).to eq("error" => "Book is not borrowed")
    end
  end

  it "returns 422 for an unknown status" do
    patch path, params: { status: "lost" }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "returns 400 with a JSON error for a malformed body" do
    patch path, params: '{"status": borrowed', headers: { "CONTENT_TYPE" => "application/json" }

    expect(response).to have_http_status(:bad_request)
    expect(json).to eq("error" => "Request body is not valid JSON")
  end

  it "returns 400 when status is missing" do
    patch path, params: {}, as: :json

    expect(response).to have_http_status(:bad_request)
  end

  it "keeps the full history across borrow and return cycles" do
    other_reader = create(:reader)

    patch path, params: { status: "borrowed", card_number: reader.card_number }, as: :json
    patch path, params: { status: "available" }, as: :json
    patch path, params: { status: "borrowed", card_number: other_reader.card_number }, as: :json

    get "/api/v1/books/#{book.serial_number}"

    expect(json["status"]).to eq("borrowed")
    expect(json["loans"].map { |loan| loan.dig("reader", "card_number") })
      .to eq([ other_reader.card_number, reader.card_number ])
  end
end
