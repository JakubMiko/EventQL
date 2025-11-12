# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::TicketBatches::CreateTicketBatch, type: :request do
  let!(:admin) { create(:user, admin: true) }
  let!(:regular_user) { create(:user, admin: false) }
  let!(:event) { create(:event, date: 1.month.from_now) }
  let(:admin_token) { Authentication.encode_token({ user_id: admin.id }) }
  let(:user_token) { Authentication.encode_token({ user_id: regular_user.id }) }

  let(:mutation) do
    <<~GRAPHQL
      mutation CreateTicketBatch($input: CreateTicketBatchInput!) {
        createTicketBatch(input: $input) {
          ticketBatch {
            id
            eventId
            availableTickets
            price
            saleStart
            saleEnd
            state
          }
          errors
        }
      }
    GRAPHQL
  end

  context "when authenticated as admin" do
    let(:headers) { { "Authorization" => "Bearer #{admin_token}" } }

    context "with valid parameters" do
      let(:variables) do
        {
          input: {
            eventId: event.id.to_s,
            availableTickets: 100,
            price: "50.00",
            saleStart: 1.day.from_now.iso8601,
            saleEnd: 2.weeks.from_now.iso8601
          }
        }
      end

      it "creates a new ticket batch" do
        post "/graphql",
          params: { query: mutation, variables: variables }.to_json,
          headers: headers.merge({ "Content-Type" => "application/json" })

        expect(TicketBatch.count).to eq(1)

        batch = TicketBatch.last
        expect(batch.event_id).to eq(event.id)
        expect(batch.available_tickets).to eq(100)
        expect(batch.price.to_s).to eq("50.0")
      end

      it "returns the created ticket batch" do
        post "/graphql",
          params: { query: mutation, variables: variables }.to_json,
          headers: headers.merge({ "Content-Type" => "application/json" })

        json = JSON.parse(response.body)
        data = json["data"]["createTicketBatch"]

        expect(data["ticketBatch"]).to be_present
        expect(data["ticketBatch"]["eventId"]).to eq(event.id.to_s)
        expect(data["ticketBatch"]["availableTickets"]).to eq(100)
        expect(data["ticketBatch"]["price"]).to eq("50.0")
        expect(data["ticketBatch"]["state"]).to eq("inactive")
        expect(data["errors"]).to be_empty
      end
    end

    context "with invalid event_id" do
      let(:variables) do
        {
          input: {
            eventId: "99999",
            availableTickets: 100,
            price: "50.00",
            saleStart: 1.day.from_now.iso8601,
            saleEnd: 2.weeks.from_now.iso8601
          }
        }
      end

      it "returns an error" do
        post "/graphql",
          params: { query: mutation, variables: variables }.to_json,
          headers: headers.merge({ "Content-Type" => "application/json" })

        json = JSON.parse(response.body)
        data = json["data"]["createTicketBatch"]

        expect(data["ticketBatch"]).to be_nil
        expect(data["errors"]).to include("Event not found")
      end
    end

    context "with sale_start after sale_end" do
      let(:variables) do
        {
          input: {
            eventId: event.id.to_s,
            availableTickets: 100,
            price: "50.00",
            saleStart: 2.weeks.from_now.iso8601,
            saleEnd: 1.day.from_now.iso8601
          }
        }
      end

      it "returns validation error" do
        post "/graphql",
          params: { query: mutation, variables: variables }.to_json,
          headers: headers.merge({ "Content-Type" => "application/json" })

        json = JSON.parse(response.body)
        data = json["data"]["createTicketBatch"]

        expect(data["ticketBatch"]).to be_nil
        expect(data["errors"]).to be_present
        expect(data["errors"].first).to include("earlier than")
      end
    end

    context "with overlapping sales periods" do
      before do
        create(:ticket_batch,
          event: event,
          sale_start: 1.day.from_now,
          sale_end: 1.week.from_now)
      end

      let(:variables) do
        {
          input: {
            eventId: event.id.to_s,
            availableTickets: 100,
            price: "50.00",
            saleStart: 3.days.from_now.iso8601,
            saleEnd: 10.days.from_now.iso8601
          }
        }
      end

      it "returns validation error" do
        post "/graphql",
          params: { query: mutation, variables: variables }.to_json,
          headers: headers.merge({ "Content-Type" => "application/json" })

        json = JSON.parse(response.body)
        data = json["data"]["createTicketBatch"]

        expect(data["ticketBatch"]).to be_nil
        expect(data["errors"].first).to include("conflicts")
      end
    end
  end

  context "when authenticated as regular user" do
    let(:headers) { { "Authorization" => "Bearer #{user_token}" } }
    let(:variables) do
      {
        input: {
          eventId: event.id.to_s,
          availableTickets: 100,
          price: "50.00",
          saleStart: 1.day.from_now.iso8601,
          saleEnd: 2.weeks.from_now.iso8601
        }
      }
    end

    it "returns authorization error" do
      post "/graphql",
        params: { query: mutation, variables: variables }.to_json,
        headers: headers.merge({ "Content-Type" => "application/json" })

      json = JSON.parse(response.body)
      expect(json["errors"]).to be_present
      expect(json["errors"].first["message"]).to eq("Admin access required")
    end
  end

  context "when not authenticated" do
    let(:variables) do
      {
        input: {
          eventId: event.id.to_s,
          availableTickets: 100,
          price: "50.00",
          saleStart: 1.day.from_now.iso8601,
          saleEnd: 2.weeks.from_now.iso8601
        }
      }
    end

    it "returns authentication error" do
      post "/graphql",
        params: { query: mutation, variables: variables }.to_json,
        headers: { "Content-Type" => "application/json" }

      json = JSON.parse(response.body)
      expect(json["errors"]).to be_present
      expect(json["errors"].first["message"]).to eq("You must be logged in to perform this action")
    end
  end
end
