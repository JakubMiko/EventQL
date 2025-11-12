# frozen_string_literal: true

module Mutations
  module TicketBatches
    class Delete < Mutations::BaseMutation
      description "Delete a ticket batch (admin only)"

      argument :id, ID, required: true, description: "ID of the ticket batch to delete"

      field :success, Boolean, null: false, description: "Whether the deletion was successful"
      field :errors, [ String ], null: false, description: "Error messages if deletion fails"

      def resolve(id:)
        require_admin!

        batch = TicketBatch.find_by(id: id)
        return { success: false, errors: [ "Ticket batch not found" ] } unless batch

        if batch.destroy
          { success: true, errors: [] }
        else
          { success: false, errors: batch.errors.full_messages }
        end
      end
    end
  end
end
