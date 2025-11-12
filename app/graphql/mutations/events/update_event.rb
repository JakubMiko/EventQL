# frozen_string_literal: true

module Mutations
  module Events
    class UpdateEvent < Mutations::BaseMutation
      description "Update an existing event (admin only)"

      # Arguments
      argument :id, ID, required: true, description: "Event ID to update"
      argument :input, Types::Inputs::UpdateEventInput, required: true

      # Return fields
      field :event, Types::EventType, null: true, description: "The updated event"
      field :errors, [ String ], null: false, description: "Error messages if update fails"

      def resolve(id:, input:)
        require_admin!

        event = ::Event.find_by(id: id)
        unless event
          return {
            event: nil,
            errors: [ "Event not found" ]
          }
        end

        result = ::Events::UpdateService.call(event, input.to_h)

        if result.success?
          {
            event: result.value!,
            errors: []
          }
        else
          {
            event: nil,
            errors: [ result.failure ]
          }
        end
      end
    end
  end
end
