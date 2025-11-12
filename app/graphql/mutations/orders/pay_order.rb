# frozen_string_literal: true

module Mutations
  module Orders
    class PayOrder < Mutations::BaseMutation
      description "Pay for an order (owner or admin only, mocked payment)"

      argument :input, Types::Inputs::PayOrderInput, required: true

      field :order, Types::OrderType, null: true, description: "The paid order"
      field :errors, [ String ], null: false, description: "Error messages if payment fails"

      def resolve(input:)
        require_authentication!

        order = ::Order.find_by(id: input.id)
        return { order: nil, errors: [ "Order not found" ] } unless order

        result = ::Orders::PayService.new(
          order: order,
          actor: current_user,
          amount: input.amount,
          payment_method: input.payment_method || "test",
          force_payment_status: input.force_payment_status
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
