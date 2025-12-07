# frozen_string_literal: true

module Types
  class OrderConnectionType < GraphQL::Types::Relay::BaseConnection
    edge_type(Types::OrderType.edge_type)

    field :total_count, Integer, null: false, description: "Total number of orders matching the query"

    def total_count
      # Use the unscoped relation to count all matching records
      # object.items is the ActiveRecord relation passed to the connection
      object.items.count
    end
  end
end
