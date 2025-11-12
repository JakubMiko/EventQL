# frozen_string_literal: true

module Queries
  module Orders
    class GetOrder < Queries::BaseQuery
      description "Get order details by ID (admin can view any, user can view own)"

      type Types::OrderType, null: true

      argument :id, ID, required: true, description: "Order ID"

      def resolve(id:)
        require_authentication!

        order = ::Order.includes(:tickets, :ticket_batch, ticket_batch: :event).find_by(id: id)
        return nil unless order

        # Admin can see any order, user can only see their own
        unless current_user.admin? || order.user_id == current_user.id
          raise GraphQL::ExecutionError, "Forbidden"
        end

        order
      end
    end
  end
end
