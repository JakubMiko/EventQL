# frozen_string_literal: true

module Types
  class TicketBatchType < Types::BaseObject
    description "A batch of tickets for sale for an event"

    field :id, ID, null: false, description: "Unique identifier"
    field :event_id, ID, null: false, description: "ID of the associated event"
    field :available_tickets, Integer, null: false, description: "Number of tickets still available for purchase"
    field :price, String, null: false, description: "Price per ticket (as decimal string)"
    field :sale_start, GraphQL::Types::ISO8601DateTime, null: false, description: "When ticket sales begin"
    field :sale_end, GraphQL::Types::ISO8601DateTime, null: false, description: "When ticket sales end"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When the batch was created"
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When the batch was last updated"

    # Computed fields
    field :state, String, null: false, description: "Current state (available, sold_out, expired, inactive)"

    # Associations
    field :event, Types::EventType, null: false, description: "The event this batch belongs to"
    field :orders, [ Types::OrderType ], null: false, description: "Orders placed for tickets from this batch"

    def price
      object.price.to_s
    end

    def state
      now = Time.current

      if object.sale_start > now
        "inactive"
      elsif object.sale_end < now
        "expired"
      elsif object.available_tickets == 0
        "sold_out"
      else
        "available"
      end
    end
  end
end
