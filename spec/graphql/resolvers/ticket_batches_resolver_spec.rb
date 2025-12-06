# frozen_string_literal: true

require "rails_helper"

RSpec.describe "TicketBatchesResolver", type: :request do
  describe "N+1 query prevention" do
    let!(:events) do
      10.times.map do |i|
        create(:event, name: "Event #{i + 1}")
      end
    end

    let!(:ticket_batches) do
      events.flat_map do |event|
        [
          create(:ticket_batch, event: event, price: 100, available_tickets: 50),
          create(:ticket_batch, event: event, price: 200, available_tickets: 25)
        ]
      end
    end

    let(:query) do
      <<~GRAPHQL
        query GetEventsWithTicketBatches {
          events(first: 10) {
            nodes {
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
      GRAPHQL
    end

    it "uses DataLoader to prevent N+1 queries" do
      # Clear any existing logs
      ActiveRecord::Base.logger = Logger.new(StringIO.new)
      query_log = StringIO.new
      ActiveRecord::Base.logger = Logger.new(query_log)

      post "/graphql", params: { query: query }

      json = JSON.parse(response.body)
      expect(json["errors"]).to be_nil

      # Count the actual SQL queries
      log_output = query_log.string
      ticket_batch_queries = log_output.scan(/SELECT.*FROM.*ticket_batches/).count

      # Should only have 1 batched query for ticket_batches (using WHERE event_id IN (...))
      # instead of 10 individual queries (one per event)
      expect(ticket_batch_queries).to eq(1)

      # Verify the query uses batching (WHERE event_id IN (...))
      expect(log_output).to include('WHERE "ticket_batches"."event_id" IN')
    end

    it "returns correct data structure" do
      post "/graphql", params: { query: query }

      json = JSON.parse(response.body)
      expect(json["errors"]).to be_nil

      nodes = json.dig("data", "events", "nodes")
      expect(nodes).to be_present
      expect(nodes.length).to eq(10)

      # Each event should have 2 ticket batches
      nodes.each do |node|
        expect(node["ticketBatches"]).to be_present
        expect(node["ticketBatches"].length).to eq(2)
        expect(node["ticketBatches"].first.keys).to contain_exactly("id", "price", "availableTickets")
      end
    end

    context "with state filtering" do
      let(:now) { Time.current }

      let!(:event_with_available) { create(:event, name: "Event with available tickets") }
      let!(:available_batch) do
        create(:ticket_batch,
          event: event_with_available,
          sale_start: now - 1.day,
          sale_end: now + 1.day,
          available_tickets: 100)
      end

      let!(:event_with_inactive) { create(:event, name: "Event with inactive tickets") }
      let!(:inactive_batch) do
        create(:ticket_batch,
          event: event_with_inactive,
          sale_start: now + 1.day,
          sale_end: now + 2.days,
          available_tickets: 100)
      end

      let!(:event_with_expired) { create(:event, name: "Event with expired tickets") }
      let!(:expired_batch) do
        create(:ticket_batch,
          event: event_with_expired,
          sale_start: now - 2.days,
          sale_end: now - 1.day,
          available_tickets: 100)
      end

      let(:query_with_state) do
        <<~GRAPHQL
          query GetEventsWithFilteredBatches($state: TicketBatchStateEnum!) {
            events(first: 20) {
              nodes {
                id
                name
                ticketBatches(state: $state) {
                  id
                  availableTickets
                }
              }
            }
          }
        GRAPHQL
      end

      it "filters by available state using DataLoader" do
        variables = { state: "AVAILABLE" }
        post "/graphql", params: { query: query_with_state, variables: variables }

        json = JSON.parse(response.body)
        expect(json["errors"]).to be_nil

        nodes = json.dig("data", "events", "nodes")
        event_with_batches = nodes.find { |n| n["name"] == "Event with available tickets" }
        event_without_batches = nodes.find { |n| n["name"] == "Event with inactive tickets" }

        expect(event_with_batches["ticketBatches"].length).to eq(1)
        expect(event_without_batches["ticketBatches"].length).to eq(0)
      end

      it "filters by inactive state using DataLoader" do
        variables = { state: "INACTIVE" }
        post "/graphql", params: { query: query_with_state, variables: variables }

        json = JSON.parse(response.body)
        expect(json["errors"]).to be_nil

        nodes = json.dig("data", "events", "nodes")
        event_with_batches = nodes.find { |n| n["name"] == "Event with inactive tickets" }
        event_without_batches = nodes.find { |n| n["name"] == "Event with available tickets" }

        expect(event_with_batches["ticketBatches"].length).to eq(1)
        expect(event_without_batches["ticketBatches"].length).to eq(0)
      end

      it "filters by expired state using DataLoader" do
        variables = { state: "EXPIRED" }
        post "/graphql", params: { query: query_with_state, variables: variables }

        json = JSON.parse(response.body)
        expect(json["errors"]).to be_nil

        nodes = json.dig("data", "events", "nodes")
        event_with_batches = nodes.find { |n| n["name"] == "Event with expired tickets" }
        event_without_batches = nodes.find { |n| n["name"] == "Event with available tickets" }

        expect(event_with_batches["ticketBatches"].length).to eq(1)
        expect(event_without_batches["ticketBatches"].length).to eq(0)
      end
    end

    context "with order argument" do
      let!(:event) { create(:event, name: "Event with ordered batches") }
      let!(:batch_1) { create(:ticket_batch, event: event, sale_start: 1.day.ago) }
      let!(:batch_2) { create(:ticket_batch, event: event, sale_start: 2.days.ago) }
      let!(:batch_3) { create(:ticket_batch, event: event, sale_start: 3.days.ago) }

      let(:query_with_order) do
        <<~GRAPHQL
          query GetEventsWithOrderedBatches($order: SortOrderEnum!) {
            events(first: 20) {
              nodes {
                id
                name
                ticketBatches(order: $order) {
                  id
                  saleStart
                }
              }
            }
          }
        GRAPHQL
      end

      it "sorts batches by sale_start descending" do
        variables = { order: "DESC" }
        post "/graphql", params: { query: query_with_order, variables: variables }

        json = JSON.parse(response.body)
        expect(json["errors"]).to be_nil

        nodes = json.dig("data", "events", "nodes")
        event_node = nodes.find { |n| n["name"] == "Event with ordered batches" }
        batches = event_node["ticketBatches"]

        expect(batches.length).to eq(3)
        # Most recent sale_start should be first (desc order)
        expect(batches[0]["id"]).to eq(batch_1.id.to_s)
        expect(batches[1]["id"]).to eq(batch_2.id.to_s)
        expect(batches[2]["id"]).to eq(batch_3.id.to_s)
      end

      it "sorts batches by sale_start ascending" do
        variables = { order: "ASC" }
        post "/graphql", params: { query: query_with_order, variables: variables }

        json = JSON.parse(response.body)
        expect(json["errors"]).to be_nil

        nodes = json.dig("data", "events", "nodes")
        event_node = nodes.find { |n| n["name"] == "Event with ordered batches" }
        batches = event_node["ticketBatches"]

        expect(batches.length).to eq(3)
        # Oldest sale_start should be first (asc order)
        expect(batches[0]["id"]).to eq(batch_3.id.to_s)
        expect(batches[1]["id"]).to eq(batch_2.id.to_s)
        expect(batches[2]["id"]).to eq(batch_1.id.to_s)
      end
    end
  end
end
