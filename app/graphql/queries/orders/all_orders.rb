# frozen_string_literal: true

module Queries
  module Orders
    class AllOrders < Queries::BaseQuery
      description "Get all orders with optional filter by user_id (admin only)"

      type [ Types::OrderType ], null: false

      argument :user_id, ID, required: false, description: "Filter orders by user ID"

      def resolve(user_id: nil)
        require_admin!

        scope = ::Order.includes(:tickets, :ticket_batch, ticket_batch: :event).order(created_at: :desc)
        scope = scope.where(user_id: user_id) if user_id.present?

        scope
      end
    end
  end
end
