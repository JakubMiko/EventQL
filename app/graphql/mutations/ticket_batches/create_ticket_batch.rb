# frozen_string_literal: true

module Mutations
  module TicketBatches
    class CreateTicketBatch < Mutations::BaseMutation
      description "Create a new ticket batch for an event (admin only)"

      argument :input, Types::Inputs::CreateTicketBatchInput, required: true

      field :ticket_batch, Types::TicketBatchType, null: true, description: "The newly created ticket batch"
      field :errors, [ String ], null: false, description: "Error messages if creation fails"

      def resolve(input:)
        require_admin!

        event = Event.find_by(id: input.event_id)
        return { ticket_batch: nil, errors: [ "Event not found" ] } unless event

        result = ::TicketBatches::CreateService.call(
          event: event,
          params: input.to_h.except(:event_id)
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
