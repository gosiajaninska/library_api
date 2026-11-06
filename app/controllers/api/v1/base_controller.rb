module Api
  module V1
    # Maps exceptions to JSON errors in one place:
    #   { "error": "message" }                      400, 404, 409
    #   { "error": "message", "details": { ... } }  422
    class BaseController < ApplicationController
      rescue_from ActionController::ParameterMissing do |error|
        render_error(error.message, :bad_request)
      end

      rescue_from ActionDispatch::Http::Parameters::ParseError do
        render_error("Request body is not valid JSON", :bad_request)
      end

      rescue_from ActiveRecord::RecordNotFound do |error|
        render_error("#{error.model || 'Record'} not found", :not_found)
      end

      rescue_from ActiveRecord::RecordInvalid do |error|
        render_error("Validation failed", :unprocessable_content, details: error.record.errors.to_hash(true))
      end

      rescue_from LibraryErrors::InvalidRequest do |error|
        render_error(error.message, :unprocessable_content)
      end

      rescue_from LibraryErrors::Conflict do |error|
        render_error(error.message, :conflict)
      end

      # Unique indexes are the last guard, e.g. two concurrent requests creating
      # a book with the same serial number: the second one gets 409, not 500.
      rescue_from ActiveRecord::RecordNotUnique do
        render_error("Conflicts with an existing record", :conflict)
      end

      private

      def render_error(message, status, details: nil)
        render json: { error: message, details: details }.compact, status: status
      end
    end
  end
end
