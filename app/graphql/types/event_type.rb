module Types
  class EventType < Types::BaseObject
    field :id, ID, null: false
    field :name, String, null: false
    field :description, String, null: true
    field :date, String, null: false
    field :category, String, null: false
    field :place, String, null: true
    field :ticket_batches, [ Types::TicketBatchType ], null: true
    field :tickets, [ Types::TicketType ], null: true
  end
end
