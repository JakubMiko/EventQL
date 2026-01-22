# frozen_string_literal: true

module Queries
  module Events
    class GetEvent < Queries::BaseQuery
      description "Get a single event by ID"

      type Types::EventType, null: true

      argument :id, ID, required: true, description: "Event ID"

      def resolve(id:)
        ::Event.includes(:ticket_batches).find_by(id: id)
      end
    end
  end
end
