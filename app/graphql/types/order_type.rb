module Types
  class OrderType < Types::BaseObject
    field :id, ID, null: false
    field :user, Types::UserType, null: false
    field :ticket_batch, Types::TicketBatchType, null: false
    field :quantity, Integer, null: false
    field :total_price, Float, null: false
    field :status, String, null: false
    field :tickets, [ Types::TicketType ], null: true
  end
end
