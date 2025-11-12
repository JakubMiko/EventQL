# frozen_string_literal: true

module Mutations
  module Events
    class CreateEvent < Mutations::BaseMutation
      description "Create a new event (admin only)"

      # Arguments - using Input Object Type
      argument :input, Types::Inputs::CreateEventInput, required: true

      # Return fields
      field :event, Types::EventType, null: true, description: "The newly created event"
      field :errors, [ String ], null: false, description: "Error messages if creation fails"

      def resolve(input:)
        require_admin!

        result = ::Events::CreateService.call(input.to_h)

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
