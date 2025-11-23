# frozen_string_literal: true

require "rails_helper"

RSpec.describe "TicketBatch Queries", type: :request do
  let!(:event) { create(:event, date: 1.month.from_now) }
  let!(:ticket_batch) do
    create(:ticket_batch,
      event: event,
      available_tickets: 100,
      price: 50.00,
      sale_start: 1.day.from_now,
      sale_end: 1.week.from_now)
  end

  describe "ticketBatch query" do
    let(:query) do
      <<~GRAPHQL
        query GetTicketBatch($id: ID!) {
          ticketBatch(id: $id) {
            id
            eventId
            availableTickets
            price
            saleStart
            saleEnd
            state
          }
        }
      GRAPHQL
    end

    context "with valid id" do
      let(:variables) { { id: ticket_batch.id.to_s } }

      it "returns the ticket batch" do
        post "/graphql",
          params: { query: query, variables: variables }.to_json,
          headers: { "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        data = json["data"]["ticketBatch"]

        expect(data).to be_present
        expect(data["id"]).to eq(ticket_batch.id.to_s)
        expect(data["eventId"]).to eq(event.id.to_s)
        expect(data["availableTickets"]).to eq(100)
        expect(data["price"]).to eq("50.0")
        expect(data["state"]).to eq("inactive")
      end
    end

    context "with invalid id" do
      let(:variables) { { id: "99999" } }

      it "returns null" do
        post "/graphql",
          params: { query: query, variables: variables }.to_json,
          headers: { "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        expect(json["data"]["ticketBatch"]).to be_nil
      end
    end
  end

  describe "event.ticketBatches field" do
    let!(:available_batch) do
      create(:ticket_batch,
        event: event,
        available_tickets: 100,
        price: 30.00,
        sale_start: 1.hour.ago,
        sale_end: 1.week.from_now)
    end

    let!(:inactive_batch) do
      create(:ticket_batch,
        event: event,
        available_tickets: 50,
        price: 40.00,
        sale_start: 1.week.from_now,
        sale_end: 2.weeks.from_now)
    end

    let!(:expired_batch) do
      create(:ticket_batch,
        event: event,
        available_tickets: 25,
        price: 20.00,
        sale_start: 3.weeks.ago,
        sale_end: 1.week.ago)
    end

    let!(:sold_out_batch) do
      create(:ticket_batch,
        event: event,
        available_tickets: 0,
        price: 60.00,
        sale_start: 1.hour.ago,
        sale_end: 1.week.from_now)
    end

    let(:query) do
      <<~GRAPHQL
        query GetEventWithTicketBatches($id: ID!, $state: TicketBatchStateEnum, $order: SortOrderEnum) {
          event(id: $id) {
            id
            name
            ticketBatches(state: $state, order: $order) {
              id
              availableTickets
              price
              saleStart
              state
            }
          }
        }
      GRAPHQL
    end

    context "filtering by state" do
      context "with state: AVAILABLE" do
        let(:variables) { { id: event.id.to_s, state: "AVAILABLE" } }

        it "returns only available ticket batches" do
          post "/graphql",
            params: { query: query, variables: variables }.to_json,
            headers: { "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          batches = json["data"]["event"]["ticketBatches"]

          expect(batches.length).to eq(1)
          expect(batches.first["id"]).to eq(available_batch.id.to_s)
          expect(batches.first["state"]).to eq("available")
        end
      end

      context "with state: INACTIVE" do
        let(:variables) { { id: event.id.to_s, state: "INACTIVE" } }

        it "returns only inactive ticket batches" do
          post "/graphql",
            params: { query: query, variables: variables }.to_json,
            headers: { "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          batches = json["data"]["event"]["ticketBatches"]

          # Both the initial ticket_batch and inactive_batch are inactive
          expect(batches.length).to eq(2)
          expect(batches.map { |b| b["state"] }.uniq).to eq([ "inactive" ])
          expect(batches.map { |b| b["id"] }).to include(inactive_batch.id.to_s, ticket_batch.id.to_s)
        end
      end

      context "with state: EXPIRED" do
        let(:variables) { { id: event.id.to_s, state: "EXPIRED" } }

        it "returns only expired ticket batches" do
          post "/graphql",
            params: { query: query, variables: variables }.to_json,
            headers: { "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          batches = json["data"]["event"]["ticketBatches"]

          expect(batches.length).to eq(1)
          expect(batches.first["id"]).to eq(expired_batch.id.to_s)
          expect(batches.first["state"]).to eq("expired")
        end
      end

      context "with state: SOLD_OUT" do
        let(:variables) { { id: event.id.to_s, state: "SOLD_OUT" } }

        it "returns only sold out ticket batches" do
          post "/graphql",
            params: { query: query, variables: variables }.to_json,
            headers: { "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          batches = json["data"]["event"]["ticketBatches"]

          expect(batches.length).to eq(1)
          expect(batches.first["id"]).to eq(sold_out_batch.id.to_s)
          expect(batches.first["state"]).to eq("sold_out")
        end
      end

      context "with state: ALL" do
        let(:variables) { { id: event.id.to_s, state: "ALL" } }

        it "returns all ticket batches" do
          post "/graphql",
            params: { query: query, variables: variables }.to_json,
            headers: { "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          batches = json["data"]["event"]["ticketBatches"]

          # Initial ticket_batch + 4 created in this context
          expect(batches.length).to eq(5)
        end
      end

      context "without state parameter (defaults to ALL)" do
        let(:variables) { { id: event.id.to_s } }

        it "returns all ticket batches" do
          post "/graphql",
            params: { query: query, variables: variables }.to_json,
            headers: { "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          batches = json["data"]["event"]["ticketBatches"]

          # Initial ticket_batch + 4 created in this context
          expect(batches.length).to eq(5)
        end
      end
    end

    context "sorting by order" do
      let!(:batch_early) do
        create(:ticket_batch,
          event: event,
          price: 30.00,
          available_tickets: 100,
          sale_start: 3.days.ago,
          sale_end: 1.week.from_now)
      end

      let!(:batch_middle) do
        create(:ticket_batch,
          event: event,
          price: 20.00,
          available_tickets: 100,
          sale_start: 2.days.ago,
          sale_end: 1.week.from_now)
      end

      let!(:batch_recent) do
        create(:ticket_batch,
          event: event,
          price: 40.00,
          available_tickets: 100,
          sale_start: 1.day.ago,
          sale_end: 1.week.from_now)
      end

      context "with order: ASC" do
        let(:variables) { { id: event.id.to_s, state: "ALL", order: "ASC" } }

        it "returns batches sorted by sale_start ascending" do
          post "/graphql",
            params: { query: query, variables: variables }.to_json,
            headers: { "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          batches = json["data"]["event"]["ticketBatches"]
          sale_starts = batches.map { |b| Time.zone.parse(b["saleStart"]) }

          expect(sale_starts).to eq(sale_starts.sort)
        end
      end

      context "with order: DESC" do
        let(:variables) { { id: event.id.to_s, state: "ALL", order: "DESC" } }

        it "returns batches sorted by sale_start descending" do
          post "/graphql",
            params: { query: query, variables: variables }.to_json,
            headers: { "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          batches = json["data"]["event"]["ticketBatches"]
          sale_starts = batches.map { |b| Time.zone.parse(b["saleStart"]) }

          expect(sale_starts).to eq(sale_starts.sort.reverse)
        end
      end
    end
  end
end
