# frozen_string_literal: true

module Queries
  module Events
    class ListEvents < Queries::BaseQuery
      description "Get all events with optional filters"

      type [ Types::EventType ], null: false

      argument :category, String, required: false, description: "Filter by category"
      argument :upcoming, Boolean, required: false, description: "Show only upcoming events"
      argument :past, Boolean, required: false, description: "Show only past events"

      def resolve(category: nil, upcoming: nil, past: nil)
        scope = ::Event.limit(100)

        # Apply filters
        scope = scope.where(category: category) if category.present?
        scope = scope.upcoming if upcoming
        scope = scope.past if past

        scope
      end
    end
  end
end
