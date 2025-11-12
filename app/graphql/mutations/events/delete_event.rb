# frozen_string_literal: true

module Mutations
  module Events
    class DeleteEvent < Mutations::BaseMutation
      description "Delete an event (admin only)"

      # Arguments
      argument :id, ID, required: true, description: "Event ID to delete"

      # Return fields
      field :success, Boolean, null: false, description: "Whether the deletion was successful"
      field :message, String, null: true, description: "Success or error message"

      def resolve(id:)
        require_admin!

        event = ::Event.find_by(id: id)
        unless event
          return {
            success: false,
            message: "Event not found"
          }
        end

        if event.destroy
          {
            success: true,
            message: "Event deleted successfully"
          }
        else
          {
            success: false,
            message: event.errors.full_messages.join(", ")
          }
        end
      end
    end
  end
end
