# frozen_string_literal: true

require "rails_helper"

RSpec.describe Queries::Events::Index, type: :request do
  describe ".resolve" do
    let(:query) do
      <<~GRAPHQL
        query GetEvents($category: String, $upcoming: Boolean, $past: Boolean) {
          events(category: $category, upcoming: $upcoming, past: $past) {
            id
            name
            description
            place
            date
            category
            past
            imageUrl
          }
        }
      GRAPHQL
    end

    # Create test data
    let!(:upcoming_music) { create(:event, :upcoming, category: "music", name: "Music Festival") }
    let!(:upcoming_theater) { create(:event, :upcoming, category: "theater", name: "Theater Show") }
    let!(:past_music) { create(:event, :past, category: "music", name: "Past Concert") }
    let!(:past_sports) { create(:event, :past, category: "sports", name: "Past Game") }

    context "without filters" do
      let(:variables) { {} }

      it "returns all events" do
        post "/graphql", params: { query: query, variables: variables }

        json = JSON.parse(response.body)
        data = json["data"]["events"]

        expect(data.length).to eq(4)
        event_names = data.map { |e| e["name"] }
        expect(event_names).to contain_exactly("Music Festival", "Theater Show", "Past Concert", "Past Game")
      end

      it "returns events with correct structure" do
        post "/graphql", params: { query: query, variables: variables }

        json = JSON.parse(response.body)
        event = json["data"]["events"].first

        expect(event.keys).to contain_exactly("id", "name", "description", "place", "date", "category", "past", "imageUrl")
      end
    end

    context "with category filter" do
      let(:variables) { { category: "music" } }

      it "returns only music events" do
        post "/graphql", params: { query: query, variables: variables }

        json = JSON.parse(response.body)
        data = json["data"]["events"]

        expect(data.length).to eq(2)
        event_names = data.map { |e| e["name"] }
        expect(event_names).to contain_exactly("Music Festival", "Past Concert")
        expect(data.all? { |e| e["category"] == "music" }).to be(true)
      end
    end

    context "with upcoming filter" do
      let(:variables) { { upcoming: true }.to_json }

      it "returns only upcoming events" do
        post "/graphql", params: { query: query, variables: variables }

        json = JSON.parse(response.body)
        data = json["data"]["events"]

        expect(data.length).to eq(2)
        event_names = data.map { |e| e["name"] }
        expect(event_names).to contain_exactly("Music Festival", "Theater Show")
        expect(data.all? { |e| e["past"] == false }).to be(true)
      end
    end

    context "with past filter" do
      let(:variables) { { past: true }.to_json }

      it "returns only past events" do
        post "/graphql", params: { query: query, variables: variables }

        json = JSON.parse(response.body)
        data = json["data"]["events"]

        expect(data.length).to eq(2)
        event_names = data.map { |e| e["name"] }
        expect(event_names).to contain_exactly("Past Concert", "Past Game")
        expect(data.all? { |e| e["past"] == true }).to be(true)
      end
    end

    context "with combined filters" do
      let(:variables) { { category: "music", upcoming: true }.to_json }

      it "returns upcoming music events only" do
        post "/graphql", params: { query: query, variables: variables }

        json = JSON.parse(response.body)
        data = json["data"]["events"]

        expect(data.length).to eq(1)
        expect(data.first["name"]).to eq("Music Festival")
        expect(data.first["category"]).to eq("music")
        expect(data.first["past"]).to be(false)
      end
    end

    context "when no events match filters" do
      let(:variables) { { category: "comedy", upcoming: true }.to_json }

      it "returns an empty array" do
        post "/graphql", params: { query: query, variables: variables }

        json = JSON.parse(response.body)
        data = json["data"]["events"]

        expect(data).to eq([])
      end
    end

    context "with ticket batches association" do
      let!(:ticket_batch) { create(:ticket_batch, event: upcoming_music) }
      let(:query_with_batches) do
        <<~GRAPHQL
          query {
            events {
              id
              name
              ticketBatches {
                id
                price
                availableTickets
              }
            }
          }
        GRAPHQL
      end

      it "includes ticket batches when requested" do
        post "/graphql", params: { query: query_with_batches }

        json = JSON.parse(response.body)
        event_with_batch = json["data"]["events"].find { |e| e["id"] == upcoming_music.id.to_s }

        expect(event_with_batch["ticketBatches"]).to be_present
        expect(event_with_batch["ticketBatches"].length).to eq(1)
        expect(event_with_batch["ticketBatches"].first["id"]).to eq(ticket_batch.id.to_s)
      end
    end
  end
end
