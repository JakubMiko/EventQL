# frozen_string_literal: true

module Queries
  module TicketBatches
    class Show < Queries::BaseQuery
      description "Get a ticket batch by ID"

      type Types::TicketBatchType, null: true

      argument :id, ID, required: true, description: "ID of the ticket batch"

      def resolve(id:)
        TicketBatch.find_by(id: id)
      end
    end
  end
end
