module Types
  class TicketType < Types::BaseObject
    field :id, ID, null: false
    field :ticket_number, String, null: false
    field :price, Float, null: false
    field :order, Types::OrderType, null: false
    field :user, Types::UserType, null: false
    field :event, Types::EventType, null: false
  end
end
