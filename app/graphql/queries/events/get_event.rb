# frozen_string_literal: true

module Queries
  module Events
    class GetEvent < Queries::BaseQuery
      description "Get a single event by ID (cached for 5 minutes)"

      type Types::EventType, null: true

      argument :id, ID, required: true, description: "Event ID"

      def resolve(id:)
        # Build cache key for single event
        cache_key = "event:#{id}"

        # Try to fetch from cache, fallback to database on error
        begin
          Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
            fetch_event(id)
          end
        rescue => e
          # Log error and fallback to database
          Rails.logger.error("Redis cache fetch failed for event #{id}: #{e.message}")
          fetch_event(id)
        end
      end

      private

      def fetch_event(id)
        ::Event.includes(:ticket_batches).find_by(id: id)
      end
    end
  end
end
