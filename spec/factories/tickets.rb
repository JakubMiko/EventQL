FactoryBot.define do
  factory :ticket do
    order { nil }
    user { nil }
    event { nil }
    ticket_number { "MyString" }
    price { "9.99" }
  end
end
