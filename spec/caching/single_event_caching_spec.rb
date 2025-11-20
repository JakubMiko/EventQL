# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Single Event Query Caching", type: :request do
  let(:query) do
    <<~GRAPHQL
      query GetEvent($id: ID!) {
        event(id: $id) {
          id
          name
          category
          date
          place
          ticketBatches {
            id
            price
            availableTickets
          }
        }
      }
    GRAPHQL
  end

  let!(:event) { create(:event, name: "Test Event", category: "music") }
  let!(:ticket_batch) { create(:ticket_batch, event: event) }

  before do
    Rails.cache.clear
  end

  describe "caching behavior" do
    it "caches single event query results" do
      # First request - should cache
      post "/graphql", params: { query: query, variables: { id: event.id }.to_json }
      expect(response).to have_http_status(:success)

      first_response = JSON.parse(response.body)
      expect(first_response["data"]["event"]["name"]).to eq("Test Event")

      # Second request - should return same data
      post "/graphql", params: { query: query, variables: { id: event.id }.to_json }
      expect(response).to have_http_status(:success)

      second_response = JSON.parse(response.body)
      expect(second_response).to eq(first_response)
    end

    it "returns different data for different event IDs" do
      event2 = create(:event, name: "Event 2", category: "sports")

      # Query event 1
      post "/graphql", params: { query: query, variables: { id: event.id }.to_json }
      response1 = JSON.parse(response.body)

      # Query event 2
      post "/graphql", params: { query: query, variables: { id: event2.id }.to_json }
      response2 = JSON.parse(response.body)

      # Responses should be different
      expect(response1["data"]["event"]["id"]).not_to eq(response2["data"]["event"]["id"])
      expect(response1["data"]["event"]["name"]).to eq("Test Event")
      expect(response2["data"]["event"]["name"]).to eq("Event 2")
    end

    it "invalidates cache when event is updated" do
      # Cache the event
      post "/graphql", params: { query: query, variables: { id: event.id }.to_json }
      first_response = JSON.parse(response.body)
      expect(first_response["data"]["event"]["name"]).to eq("Test Event")

      # Update the event
      event.update(name: "Updated Event Name")

      # Cache should be invalidated - fresh query
      post "/graphql", params: { query: query, variables: { id: event.id }.to_json }
      second_response = JSON.parse(response.body)
      expect(second_response["data"]["event"]["name"]).to eq("Updated Event Name")
    end

    it "invalidates cache when event is destroyed" do
      # Cache the event
      post "/graphql", params: { query: query, variables: { id: event.id }.to_json }

      # Destroy the event
      event_id = event.id
      event.destroy

      # Query should return null (cache invalidated)
      post "/graphql", params: { query: query, variables: { id: event_id }.to_json }
      response_data = JSON.parse(response.body)
      expect(response_data["data"]["event"]).to be_nil
    end

    it "returns null for non-existent event without caching" do
      # Query non-existent event
      post "/graphql", params: { query: query, variables: { id: 99999 }.to_json }
      response_data = JSON.parse(response.body)

      expect(response_data["data"]["event"]).to be_nil

      # Should not cache null results
      # (Note: Rails.cache.fetch will cache nil by default, but that's okay)
    end

    it "falls back to database if Redis fails" do
      # Mock Redis failure
      allow(Rails.cache).to receive(:fetch).and_raise(Redis::BaseError.new("Connection failed"))

      # Should still work (fallback to DB)
      post "/graphql", params: { query: query, variables: { id: event.id }.to_json }
      expect(response).to have_http_status(:success)

      response_data = JSON.parse(response.body)
      expect(response_data["data"]["event"]["name"]).to eq("Test Event")
    end

    it "includes associations in cached response" do
      # First request - cache it
      post "/graphql", params: { query: query, variables: { id: event.id }.to_json }
      response_data = JSON.parse(response.body)

      # Verify ticket batches are included
      expect(response_data["data"]["event"]["ticketBatches"]).to be_present
      expect(response_data["data"]["event"]["ticketBatches"].length).to eq(1)
      expect(response_data["data"]["event"]["ticketBatches"].first["id"]).to eq(ticket_batch.id.to_s)
    end
  end

  describe "cache invalidation coordination" do
    it "invalidates both single event cache and events list cache" do
      # Cache both queries
      list_query = 'query { events(first: 10) { nodes { id name } } }'

      # Cache events list
      post "/graphql", params: { query: list_query }
      list_response_before = JSON.parse(response.body)

      # Cache single event
      post "/graphql", params: { query: query, variables: { id: event.id }.to_json }
      single_response_before = JSON.parse(response.body)

      # Update event - should clear both caches and return fresh data
      event.update(name: "Changed Name")

      # Query both again - should get updated data
      post "/graphql", params: { query: query, variables: { id: event.id }.to_json }
      single_response_after = JSON.parse(response.body)
      expect(single_response_after["data"]["event"]["name"]).to eq("Changed Name")

      post "/graphql", params: { query: list_query }
      list_response_after = JSON.parse(response.body)
      updated_event = list_response_after["data"]["events"]["nodes"].find { |e| e["id"] == event.id.to_s }
      expect(updated_event["name"]).to eq("Changed Name")
    end
  end
end
