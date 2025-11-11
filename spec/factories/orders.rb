FactoryBot.define do
  factory :order do
    user { nil }
    ticket_batch { nil }
    quantity { 1 }
    total_price { "9.99" }
    status { "MyString" }
  end
end
