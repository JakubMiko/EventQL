module Types
  class UserType < Types::BaseObject
    field :id, ID, null: false
    field :email, String, null: false
    field :first_name, String, null: true
    field :last_name, String, null: true
    field :admin, Boolean, null: false
    field :created_at, String, null: false
    field :tickets, [ Types::TicketType ], null: true
    field :orders, [ Types::OrderType ], null: true
  end
end
