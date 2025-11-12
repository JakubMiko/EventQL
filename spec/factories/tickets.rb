FactoryBot.define do
  factory :ticket do
    order
    user
    event
    price { 25.0 }
    sequence(:ticket_number) { |n| "TICKET-#{n.to_s.rjust(10, '0')}" }
  end
end
