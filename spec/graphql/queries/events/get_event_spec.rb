# frozen_string_literal: true

require "rails_helper"

RSpec.describe Queries::Events::GetEvent, type: :request do
  describe ".resolve" do
    let!(:event) { create(:event, name: "Test Event", category: "music") }
    let!(:ticket_batch) { create(:ticket_batch, event: event, price: 50.0) }

    let(:query) do
      <<~GRAPHQL
        query GetEvent($id: ID!) {
          event(id: $id) {
            id
            name
            description
            place
            date
            category
            createdAt
            updatedAt
            ticketBatches {
              id
              price
              availableTickets
            }
          }
        }
      GRAPHQL
    end

    context "when event exists" do
      let(:variables) { { id: event.id } }

      it "returns the event" do
        post "/graphql", params: { query: query, variables: variables }

        json = JSON.parse(response.body)
        data = json["data"]["event"]

        expect(data).to be_present
        expect(data["id"]).to eq(event.id.to_s)
        expect(data["name"]).to eq("Test Event")
        expect(data["category"]).to eq("music")
      end

      it "includes all requested fields" do
        post "/graphql", params: { query: query, variables: variables }

        json = JSON.parse(response.body)
        data = json["data"]["event"]

        expect(data.keys).to contain_exactly(
          "id", "name", "description", "place", "date", "category",
          "createdAt", "updatedAt", "ticketBatches"
        )
      end

      it "includes ticket batches" do
        post "/graphql", params: { query: query, variables: variables }

        json = JSON.parse(response.body)
        data = json["data"]["event"]

        expect(data["ticketBatches"]).to be_present
        expect(data["ticketBatches"].length).to eq(1)
        expect(data["ticketBatches"].first["id"]).to eq(ticket_batch.id.to_s)
        expect(data["ticketBatches"].first["price"]).to eq("50.0")
      end
    end

    context "when event does not exist" do
      let(:variables) { { id: 99999 } }

      it "returns null" do
        post "/graphql", params: { query: query, variables: variables }

        json = JSON.parse(response.body)
        data = json["data"]["event"]

        expect(data).to be_nil
      end
    end

    context "with minimal query" do
      let(:minimal_query) do
        <<~GRAPHQL
          query GetEvent($id: ID!) {
            event(id: $id) {
              id
              name
            }
          }
        GRAPHQL
      end
      let(:variables) { { id: event.id } }

      it "returns only requested fields" do
        post "/graphql", params: { query: minimal_query, variables: variables }

        json = JSON.parse(response.body)
        data = json["data"]["event"]

        expect(data.keys).to contain_exactly("id", "name")
        expect(data["id"]).to eq(event.id.to_s)
        expect(data["name"]).to eq("Test Event")
      end
    end
  end
end
