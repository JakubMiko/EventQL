FactoryBot.define do
  factory :ticket_batch do
    event { nil }
    price { "9.99" }
    total_quantity { 1 }
    available_quantity { 1 }
  end
end
