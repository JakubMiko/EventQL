# frozen_string_literal: true

module Mutations
  module Orders
    class Cancel < Mutations::BaseMutation
      description "Cancel an order (owner or admin only)"

      argument :input, Types::Inputs::CancelOrderInput, required: true

      field :order, Types::OrderType, null: true, description: "The cancelled order"
      field :errors, [ String ], null: false, description: "Error messages if cancellation fails"

      def resolve(input:)
        require_authentication!

        order = ::Order.find_by(id: input.id)
        return { order: nil, errors: [ "Order not found" ] } unless order

        result = ::Orders::CancelService.new(
          order: order,
          actor: current_user
        ).call

        if result.success?
          {
            order: result.value!,
            errors: []
          }
        else
          {
            order: nil,
            errors: [ result.failure ]
          }
        end
      end
    end
  end
end
