# frozen_string_literal: true

module Mutations
  module Orders
    class Create < Mutations::BaseMutation
      description "Create a new order (authenticated user)"

      argument :input, Types::Inputs::CreateOrderInput, required: true

      field :order, Types::OrderType, null: true, description: "The newly created order with generated tickets"
      field :errors, [ String ], null: false, description: "Error messages if creation fails"

      def resolve(input:)
        require_authentication!

        ticket_batch = ::TicketBatch.find_by(id: input.ticket_batch_id)
        return { order: nil, errors: [ "Ticket batch not found" ] } unless ticket_batch

        result = ::Orders::CreateService.new(
          ticket_batch: ticket_batch,
          quantity: input.quantity,
          current_user: current_user
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
