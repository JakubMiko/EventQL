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

        # Cache only IDs (small payload) to avoid deserializing 15K events (~1MB)
        event_ids = begin
          Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
            fetch_event_ids(category: category, upcoming: upcoming, past: past)
          end
        rescue => e
          Rails.logger.error("Redis cache fetch failed: #{e.message}, falling back to database")
          fetch_event_ids(category: category, upcoming: upcoming, past: past)
        end

        # Fetch fresh records using cached IDs (1 DB query on cache hit - acceptable tradeoff)
        ::Event.where(id: event_ids).order(date: :desc)
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

      def fetch_event_ids(category:, upcoming:, past:)
        scope = ::Event.all

        # Apply filters
        scope = scope.where(category: category) if category.present?
        scope = scope.upcoming if upcoming
        scope = scope.past if past

        # Return only IDs - small array that's fast to cache/deserialize
        scope.order(date: :desc).pluck(:id)
      end
    end
  end
end
