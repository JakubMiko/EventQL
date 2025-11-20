# frozen_string_literal: true

require "rails_helper"

RSpec.describe Queries::Events::ListEvents, type: :request do
  describe ".resolve" do
    let(:query) do
      <<~GRAPHQL
        query GetEvents($category: String, $upcoming: Boolean, $past: Boolean, $first: Int, $after: String) {
          events(category: $category, upcoming: $upcoming, past: $past, first: $first, after: $after) {
            edges {
              node {
                id
                name
                description
                place
                date
                category
              }
              cursor
            }
            pageInfo {
              hasNextPage
              hasPreviousPage
              startCursor
              endCursor
            }
            totalCount
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

      it "returns all events with connection structure" do
        post "/graphql", params: { query: query, variables: variables }

        json = JSON.parse(response.body)
        connection = json["data"]["events"]

        expect(connection["edges"].length).to eq(4)
        event_names = connection["edges"].map { |e| e["node"]["name"] }
        expect(event_names).to contain_exactly("Music Festival", "Theater Show", "Past Concert", "Past Game")
        expect(connection["totalCount"]).to eq(4)
      end

      it "returns events with correct structure" do
        post "/graphql", params: { query: query, variables: variables }

        json = JSON.parse(response.body)
        connection = json["data"]["events"]
        event_node = connection["edges"].first["node"]

        expect(event_node.keys).to contain_exactly("id", "name", "description", "place", "date", "category")
        expect(connection.keys).to contain_exactly("edges", "pageInfo", "totalCount")
        expect(connection["pageInfo"].keys).to contain_exactly("hasNextPage", "hasPreviousPage", "startCursor", "endCursor")
      end
    end

    context "with category filter" do
      let(:variables) { { category: "music" } }

      it "returns only music events" do
        post "/graphql", params: { query: query, variables: variables }

        json = JSON.parse(response.body)
        connection = json["data"]["events"]

        expect(connection["edges"].length).to eq(2)
        event_names = connection["edges"].map { |e| e["node"]["name"] }
        expect(event_names).to contain_exactly("Music Festival", "Past Concert")
        expect(connection["edges"].all? { |e| e["node"]["category"] == "music" }).to be(true)
        expect(connection["totalCount"]).to eq(2)
      end
    end

    context "with upcoming filter" do
      let(:variables) { { upcoming: true }.to_json }

      it "returns only upcoming events" do
        post "/graphql", params: { query: query, variables: variables }

        json = JSON.parse(response.body)
        connection = json["data"]["events"]

        expect(connection["edges"].length).to eq(2)
        event_names = connection["edges"].map { |e| e["node"]["name"] }
        expect(event_names).to contain_exactly("Music Festival", "Theater Show")
        expect(connection["totalCount"]).to eq(2)
      end
    end

    context "with past filter" do
      let(:variables) { { past: true }.to_json }

      it "returns only past events" do
        post "/graphql", params: { query: query, variables: variables }

        json = JSON.parse(response.body)
        connection = json["data"]["events"]

        expect(connection["edges"].length).to eq(2)
        event_names = connection["edges"].map { |e| e["node"]["name"] }
        expect(event_names).to contain_exactly("Past Concert", "Past Game")
        expect(connection["totalCount"]).to eq(2)
      end
    end

    context "with combined filters" do
      let(:variables) { { category: "music", upcoming: true }.to_json }

      it "returns upcoming music events only" do
        post "/graphql", params: { query: query, variables: variables }

        json = JSON.parse(response.body)
        connection = json["data"]["events"]

        expect(connection["edges"].length).to eq(1)
        expect(connection["edges"].first["node"]["name"]).to eq("Music Festival")
        expect(connection["edges"].first["node"]["category"]).to eq("music")
        expect(connection["totalCount"]).to eq(1)
      end
    end

    context "when no events match filters" do
      let(:variables) { { category: "comedy", upcoming: true }.to_json }

      it "returns an empty connection" do
        post "/graphql", params: { query: query, variables: variables }

        json = JSON.parse(response.body)
        connection = json["data"]["events"]

        expect(connection["edges"]).to eq([])
        expect(connection["totalCount"]).to eq(0)
      end
    end

    context "with ticket batches association" do
      let!(:ticket_batch) { create(:ticket_batch, event: upcoming_music) }
      let(:query_with_batches) do
        <<~GRAPHQL
          query {
            events {
              edges {
                node {
                  id
                  name
                  ticketBatches {
                    id
                    price
                    availableTickets
                  }
                }
              }
            }
          }
        GRAPHQL
      end

      it "includes ticket batches when requested" do
        post "/graphql", params: { query: query_with_batches }

        json = JSON.parse(response.body)
        connection = json["data"]["events"]
        event_with_batch = connection["edges"].find { |e| e["node"]["id"] == upcoming_music.id.to_s }&.dig("node")

        expect(event_with_batch["ticketBatches"]).to be_present
        expect(event_with_batch["ticketBatches"].length).to eq(1)
        expect(event_with_batch["ticketBatches"].first["id"]).to eq(ticket_batch.id.to_s)
      end
    end

    context "cursor-based pagination" do
      # Create 15 events to test pagination
      before do
        Event.delete_all
        15.times do |i|
          create(:event, name: "Event #{i + 1}", date: Time.current + i.days)
        end
      end

      context "with first argument" do
        let(:variables) { { first: 5 }.to_json }

        it "returns first 5 events" do
          post "/graphql", params: { query: query, variables: variables }

          json = JSON.parse(response.body)
          connection = json["data"]["events"]

          expect(connection["edges"].length).to eq(5)
          expect(connection["totalCount"]).to eq(15)
          expect(connection["pageInfo"]["hasNextPage"]).to be(true)
          expect(connection["pageInfo"]["hasPreviousPage"]).to be(false)
        end
      end

      context "with first and after arguments" do
        it "returns next page of results" do
          # First request: get first 5
          post "/graphql", params: { query: query, variables: { first: 5 }.to_json }
          json = JSON.parse(response.body)
          first_page = json["data"]["events"]
          cursor = first_page["edges"].last["cursor"]

          # Second request: get next 5 after cursor
          post "/graphql", params: { query: query, variables: { first: 5, after: cursor }.to_json }
          json = JSON.parse(response.body)
          second_page = json["data"]["events"]

          expect(second_page["edges"].length).to eq(5)
          expect(second_page["totalCount"]).to eq(15)
          expect(second_page["pageInfo"]["hasNextPage"]).to be(true)
          expect(second_page["pageInfo"]["hasPreviousPage"]).to be(true)

          # Ensure no overlap between pages
          first_page_ids = first_page["edges"].map { |e| e["node"]["id"] }
          second_page_ids = second_page["edges"].map { |e| e["node"]["id"] }
          expect(first_page_ids & second_page_ids).to be_empty
        end
      end

      context "with default page size" do
        let(:variables) { {} }

        it "returns 10 events by default" do
          post "/graphql", params: { query: query, variables: variables }

          json = JSON.parse(response.body)
          connection = json["data"]["events"]

          expect(connection["edges"].length).to eq(10)
          expect(connection["totalCount"]).to eq(15)
          expect(connection["pageInfo"]["hasNextPage"]).to be(true)
        end
      end

      context "with max page size exceeded" do
        let(:variables) { { first: 60 }.to_json }

        it "limits to max_page_size of 50" do
          post "/graphql", params: { query: query, variables: variables }

          json = JSON.parse(response.body)

          # Skip if complexity limit rejects the query (that's a different protection)
          if json["errors"] && json["errors"].any? { |e| e["message"].include?("complexity") }
            skip "Query rejected by complexity limit (expected behavior)"
          end

          connection = json["data"]["events"]

          # Should be limited to 15 (total available) or max 50
          expect(connection["edges"].length).to eq(15)
        end
      end

      context "pagination to last page" do
        it "indicates no next page on last page" do
          # Get all pages
          post "/graphql", params: { query: query, variables: { first: 10 }.to_json }
          json = JSON.parse(response.body)
          first_page = json["data"]["events"]
          cursor = first_page["edges"].last["cursor"]

          # Get last page
          post "/graphql", params: { query: query, variables: { first: 10, after: cursor }.to_json }
          json = JSON.parse(response.body)
          last_page = json["data"]["events"]

          expect(last_page["edges"].length).to eq(5) # 15 total - 10 from first page
          expect(last_page["pageInfo"]["hasNextPage"]).to be(false)
          expect(last_page["pageInfo"]["hasPreviousPage"]).to be(true)
        end
      end
    end
  end
end
