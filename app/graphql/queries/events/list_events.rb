# frozen_string_literal: true

module Queries
  module Events
    class ListEvents < Queries::BaseQuery
      description "Get all events with optional filters (cached for 5 minutes)"

      type Types::EventConnectionType, null: false

      argument :category, String, required: false, description: "Filter by category"
      argument :upcoming, Boolean, required: false, description: "Show only upcoming events"
      argument :past, Boolean, required: false, description: "Show only past events"

      def resolve(category: nil, upcoming: nil, past: nil)
        # Build cache key from query parameters
        cache_key = build_cache_key(category: category, upcoming: upcoming, past: past)

        # Try to fetch from cache, fallback to database on error
        begin
          Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
            fetch_events(category: category, upcoming: upcoming, past: past)
          end
        rescue => e
          # Log error and fallback to database
          Rails.logger.error("Redis cache fetch failed: #{e.message}, falling back to database")
          fetch_events(category: category, upcoming: upcoming, past: past)
        end
      end

      private

      def build_cache_key(category:, upcoming:, past:)
        # Create unique cache key based on query parameters
        key_parts = [
          "events_query",
          "v1", # Version for cache busting if query logic changes
          category.presence || "all_categories",
          upcoming ? "upcoming" : nil,
          past ? "past" : nil
        ].compact

        key_parts.join(":")
      end

      def fetch_events(category:, upcoming:, past:)
        scope = ::Event.all

        # Apply filters
        scope = scope.where(category: category) if category.present?
        scope = scope.upcoming if upcoming
        scope = scope.past if past

        # Return array of event records to cache (not a relation)
        # .to_a ensures we cache actual records, resulting in 0 DB queries on cache hit
        scope.order(date: :desc).to_a
      end
    end
  end
end
