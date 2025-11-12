# frozen_string_literal: true

module Types
  class UserType < Types::BaseObject
    description "A user of the application"

    field :id, ID, null: false
    field :email, String, null: false
    field :first_name, String, null: true
    field :last_name, String, null: true
    field :admin, Boolean, null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    # Associations
    field :tickets, [ Types::TicketType ], null: false
    field :orders, [ Types::OrderType ], null: false
  end
end
