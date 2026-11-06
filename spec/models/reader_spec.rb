require "rails_helper"

RSpec.describe Reader, type: :model do
  subject(:reader) { build(:reader) }

  invalid_card_numbers = [
    "12345",                                  # too short
    "1234567",                                # too long
    "12a456",                                 # contains a letter
    "123 456",                                # inner space
    "123\n456",                               # inner newline (guards against ^$ vs \A\z)
    "-12345",                                 # sign
    "\uFF11\uFF12\uFF13\uFF14\uFF15\uFF16"    # full-width digits
  ]

  it "has a valid factory" do
    expect(reader).to be_valid
  end

  describe "card_number" do
    it "is normalized by stripping surrounding whitespace" do
      reader.card_number = " 123456 "

      expect(reader.card_number).to eq("123456")
    end

    it "is required and reports only the blank error" do
      reader.card_number = nil

      expect(reader).not_to be_valid
      expect(reader.errors.details[:card_number]).to eq([ { error: :blank } ])
    end

    it "must be unique" do
      create(:reader, card_number: "123456")
      reader.card_number = "123456"

      expect(reader).not_to be_valid
      expect(reader.errors).to be_of_kind(:card_number, :taken)
    end

    it "accepts six digits with leading zeros" do
      reader.card_number = "000123"

      expect(reader).to be_valid
      expect(reader.card_number).to eq("000123")
    end

    context "with an invalid format" do
      invalid_card_numbers.each do |value|
        it "rejects #{value.inspect}" do
          reader.card_number = value

          expect(reader).not_to be_valid
          expect(reader.errors).to be_of_kind(:card_number, :invalid)
        end
      end
    end
  end

  describe "email" do
    it "is normalized by stripping surrounding whitespace and converting to lowercase" do
      reader.email = "  John.Doe@Example.COM "

      expect(reader.email).to eq("john.doe@example.com")
    end

    it "is required and reports only the blank error" do
      reader.email = nil

      expect(reader).not_to be_valid
      expect(reader.errors.details[:email]).to eq([ { error: :blank } ])
    end

    it "must be unique regardless of case and surrounding whitespace" do
      create(:reader, email: "john.doe@example.com")
      reader.email = " JOHN.DOE@Example.com "

      expect(reader).not_to be_valid
      expect(reader.errors).to be_of_kind(:email, :taken)
    end

    context "with an invalid format" do
      [
        "john",
        "john@",
        "@example.com",
        "john@@example.com",
        "john doe@example.com"
      ].each do |value|
        it "rejects #{value.inspect}" do
          reader.email = value

          expect(reader).not_to be_valid
          expect(reader.errors).to be_of_kind(:email, :invalid)
        end
      end
    end
  end

  describe "full_name" do
    it "is normalized by stripping surrounding whitespace" do
      reader.full_name = "  John Doe  "

      expect(reader.full_name).to eq("John Doe")
    end

    it "is required" do
      reader.full_name = nil

      expect(reader).not_to be_valid
      expect(reader.errors).to be_of_kind(:full_name, :blank)
    end
  end

  describe "#destroy" do
    it "is not allowed when the reader has loans (history must be kept)" do
      loan = create(:loan)

      expect { loan.reader.destroy }.to raise_error(ActiveRecord::DeleteRestrictionError)
    end
  end

  describe "database constraints" do
    context "unique indexes" do
      it "enforces card_number uniqueness" do
        create(:reader, card_number: "123456")
        record = build(:reader, card_number: "123456")

        expect { record.save!(validate: false) }
          .to raise_error(ActiveRecord::RecordNotUnique, /index_readers_on_card_number/)
      end

      it "enforces case-insensitive email uniqueness at the database level (citext)" do
        create(:reader, email: "john.doe@example.com")

        # Raw SQL bypasses both validations and normalization,
        # so only the citext unique index can stop this insert.
        expect {
          Reader.connection.execute(<<~SQL)
            INSERT INTO readers (full_name, card_number, email, created_at, updated_at)
            VALUES ('John Doe', '654321', 'JOHN.DOE@EXAMPLE.COM', NOW(), NOW())
          SQL
        }.to raise_error(ActiveRecord::RecordNotUnique, /index_readers_on_email/)
      end
    end

    context "check constraints" do
      invalid_card_numbers.each do |value|
        it "rejects #{value.inspect} at the database level" do
          record = build(:reader, card_number: value)

          expect { record.save!(validate: false) }
            .to raise_error(ActiveRecord::CheckViolation, /readers_card_number_format/)
        end
      end

      it "enforces not blank on card_number via the format constraint" do
        record = build(:reader, card_number: "   ")

        expect { record.save!(validate: false) }
          .to raise_error(ActiveRecord::CheckViolation, /readers_card_number_format/)
      end

      %i[email full_name].each do |attribute|
        it "enforces not blank on #{attribute}" do
          record = build(:reader, attribute => "   ")

          expect { record.save!(validate: false) }
            .to raise_error(ActiveRecord::CheckViolation, /readers_#{attribute}_not_blank/)
        end
      end
    end

    context "NOT NULL constraints" do
      %i[card_number email full_name].each do |attribute|
        it "enforces NOT NULL on #{attribute}" do
          record = build(:reader, attribute => nil)

          expect { record.save!(validate: false) }
            .to raise_error(ActiveRecord::NotNullViolation, /"#{attribute}"/)
        end
      end
    end
  end
end
