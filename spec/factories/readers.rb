FactoryBot.define do
  factory :reader do
    sequence(:card_number) { |n| format("%06d", n) }
    sequence(:email) { |n| "reader#{n}@example.com" }
    full_name { Faker::Name.name }
  end
end
