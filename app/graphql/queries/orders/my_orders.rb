# frozen_string_literal: true

module Queries
  module Orders
    class MyOrders < Queries::BaseQuery
      description "Get all orders for the current authenticated user with pagination"

      type Types::OrderConnectionType, null: false

      def resolve
        require_authentication!

        ::Order
          .where(user_id: current_user.id)
          .includes(:tickets, :ticket_batch, ticket_batch: :event)
          .order(created_at: :desc)
      end
    end
  end
end
