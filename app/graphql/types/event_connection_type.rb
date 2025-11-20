# frozen_string_literal: true

module Types
  class EventConnectionType < GraphQL::Types::Relay::BaseConnection
    edge_type(Types::EventType.edge_type)

    field :total_count, Integer, null: false, description: "Total number of events matching the query"

    def total_count
      # Use the unscoped relation to count all matching records
      # object.items is the ActiveRecord relation passed to the connection
      object.items.count
    end
  end
end
