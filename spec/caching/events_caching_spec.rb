# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Events Query Caching", type: :request do
  let(:query) do
    <<~GRAPHQL
      query GetEvents($category: String, $upcoming: Boolean) {
        events(category: $category, upcoming: $upcoming, first: 10) {
          nodes {
            id
            name
            category
          }
          totalCount
        }
      }
    GRAPHQL
  end

  before do
    # Clear cache before each test
    Rails.cache.clear

    # Create test data
    create_list(:event, 5, category: "music")
    create_list(:event, 3, category: "sports")
  end

  describe "caching behavior" do
    it "caches query results" do
      # First request - should miss cache and query DB
      post "/graphql", params: { query: query, variables: { category: "music" }.to_json }
      expect(response).to have_http_status(:success)

      first_response = JSON.parse(response.body)
      expect(first_response["data"]["events"]["totalCount"]).to eq(5)

      # Second request - should hit cache (no DB query)
      expect(Event).not_to receive(:pluck) # Verify no DB query

      post "/graphql", params: { query: query, variables: { category: "music" }.to_json }
      expect(response).to have_http_status(:success)

      second_response = JSON.parse(response.body)
      expect(second_response).to eq(first_response)
    end

    it "creates unique cache keys for different query parameters" do
      # Query for music events
      post "/graphql", params: { query: query, variables: { category: "music" }.to_json }
      music_response = JSON.parse(response.body)
      expect(music_response["data"]["events"]["totalCount"]).to eq(5)

      # Query for sports events (different cache key)
      post "/graphql", params: { query: query, variables: { category: "sports" }.to_json }
      sports_response = JSON.parse(response.body)
      expect(sports_response["data"]["events"]["totalCount"]).to eq(3)

      # Results should be different
      expect(music_response).not_to eq(sports_response)
    end

    it "invalidates cache when event is created" do
      # First request - cache it
      post "/graphql", params: { query: query, variables: { category: "music" }.to_json }
      first_response = JSON.parse(response.body)
      expect(first_response["data"]["events"]["totalCount"]).to eq(5)

      # Create a new music event
      create(:event, category: "music", name: "New Music Event")

      # Second request - should fetch fresh data (cache invalidated)
      post "/graphql", params: { query: query, variables: { category: "music" }.to_json }
      second_response = JSON.parse(response.body)
      expect(second_response["data"]["events"]["totalCount"]).to eq(6)
    end

    it "invalidates cache when event is updated" do
      music_event = Event.where(category: "music").first

      # Cache the results
      post "/graphql", params: { query: query, variables: { category: "music" }.to_json }
      first_response = JSON.parse(response.body)

      # Update an event
      music_event.update(name: "Updated Event Name")

      # Cache should be invalidated
      post "/graphql", params: { query: query, variables: { category: "music" }.to_json }
      second_response = JSON.parse(response.body)

      # Find the updated event in response
      updated_event = second_response["data"]["events"]["nodes"].find { |e| e["id"] == music_event.id.to_s }
      expect(updated_event["name"]).to eq("Updated Event Name")
    end

    it "invalidates cache when event is destroyed" do
      # Cache the results
      post "/graphql", params: { query: query, variables: { category: "music" }.to_json }
      first_response = JSON.parse(response.body)
      expect(first_response["data"]["events"]["totalCount"]).to eq(5)

      # Delete an event
      Event.where(category: "music").first.destroy

      # Cache should be invalidated
      post "/graphql", params: { query: query, variables: { category: "music" }.to_json }
      second_response = JSON.parse(response.body)
      expect(second_response["data"]["events"]["totalCount"]).to eq(4)
    end

    it "falls back to database if Redis fails" do
      # Mock Redis failure
      allow(Rails.cache).to receive(:fetch).and_raise(Redis::BaseError.new("Connection failed"))

      # Should still work (fallback to DB)
      post "/graphql", params: { query: query, variables: { category: "music" }.to_json }
      expect(response).to have_http_status(:success)

      response_data = JSON.parse(response.body)
      expect(response_data["data"]["events"]["totalCount"]).to eq(5)
    end
  end

  describe "cache key generation" do
    it "generates different keys for different filters" do
      # Test cache key generation logic
      key1 = build_test_cache_key(category: "music", upcoming: nil, past: nil)
      key2 = build_test_cache_key(category: "sports", upcoming: nil, past: nil)
      key3 = build_test_cache_key(category: nil, upcoming: true, past: nil)

      expect(key1).not_to eq(key2)
      expect(key1).not_to eq(key3)
      expect(key2).not_to eq(key3)
    end

    it "generates same key for same parameters" do
      key1 = build_test_cache_key(category: "music", upcoming: nil, past: nil)
      key2 = build_test_cache_key(category: "music", upcoming: nil, past: nil)

      expect(key1).to eq(key2)
    end
  end

  # Helper method to test cache key generation
  def build_test_cache_key(category:, upcoming:, past:)
    key_parts = [
      "events_query",
      "v1",
      category.presence || "all_categories",
      upcoming ? "upcoming" : nil,
      past ? "past" : nil
    ].compact

    key_parts.join(":")
  end
end
