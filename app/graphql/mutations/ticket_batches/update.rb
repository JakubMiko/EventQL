# frozen_string_literal: true

module Mutations
  module TicketBatches
    class Update < Mutations::BaseMutation
      description "Update an existing ticket batch (admin only)"

      argument :id, ID, required: true, description: "ID of the ticket batch to update"
      argument :input, Types::Inputs::UpdateTicketBatchInput, required: true

      field :ticket_batch, Types::TicketBatchType, null: true, description: "The updated ticket batch"
      field :errors, [ String ], null: false, description: "Error messages if update fails"

      def resolve(id:, input:)
        require_admin!

        batch = TicketBatch.find_by(id: id)
        return { ticket_batch: nil, errors: [ "Ticket batch not found" ] } unless batch

        result = ::TicketBatches::UpdateService.call(
          event: batch.event,
          ticket_batch: batch,
          params: input.to_h
        )

        if result.success?
          {
            ticket_batch: result.value!,
            errors: []
          }
        else
          {
            ticket_batch: nil,
            errors: [ result.failure ]
          }
        end
      end
    end
  end
end
