module Types
  class TicketBatchType < Types::BaseObject
    field :id, ID, null: false
    field :event, Types::EventType, null: false
    field :price, Float, null: false
    field :available_tickets, Integer, null: false
    field :sale_start, String, null: true
    field :sale_end, String, null: true
  end
end
