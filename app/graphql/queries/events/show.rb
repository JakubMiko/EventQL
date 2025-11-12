# frozen_string_literal: true

module Queries
  module Events
    class Show < Queries::BaseQuery
      description "Get full event data by ID (no auth required)"

      type Types::EventType, null: true
      argument :id, ID, required: true, description: "Event ID"

      def resolve(id:)
        event = Event.find_by(id: id)
         raise GraphQL::ExecutionError, "Event not found" unless event

        event
      end
    end
  end
end
