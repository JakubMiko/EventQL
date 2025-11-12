# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::TicketBatches::Update, type: :request do
  let!(:admin) { create(:user, admin: true) }
  let!(:regular_user) { create(:user, admin: false) }
  let!(:event) { create(:event, date: 1.month.from_now) }
  let!(:ticket_batch) do
    create(:ticket_batch,
      event: event,
      available_tickets: 50,
      price: 30.00,
      sale_start: 1.day.from_now,
      sale_end: 1.week.from_now)
  end
  let(:admin_token) { Authentication.encode_token({ user_id: admin.id }) }
  let(:user_token) { Authentication.encode_token({ user_id: regular_user.id }) }

  let(:mutation) do
    <<~GRAPHQL
      mutation UpdateTicketBatch($id: ID!, $input: UpdateTicketBatchInput!) {
        updateTicketBatch(id: $id, input: $input) {
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
          id: ticket_batch.id.to_s,
          input: {
            availableTickets: 100,
            price: "75.00"
          }
        }
      end

      it "updates the ticket batch" do
        post "/graphql",
          params: { query: mutation, variables: variables }.to_json,
          headers: headers.merge({ "Content-Type" => "application/json" })

        ticket_batch.reload
        expect(ticket_batch.available_tickets).to eq(100)
        expect(ticket_batch.price.to_s).to eq("75.0")
      end

      it "returns the updated ticket batch" do
        post "/graphql",
          params: { query: mutation, variables: variables }.to_json,
          headers: headers.merge({ "Content-Type" => "application/json" })

        json = JSON.parse(response.body)
        data = json["data"]["updateTicketBatch"]

        expect(data["ticketBatch"]).to be_present
        expect(data["ticketBatch"]["id"]).to eq(ticket_batch.id.to_s)
        expect(data["ticketBatch"]["availableTickets"]).to eq(100)
        expect(data["ticketBatch"]["price"]).to eq("75.0")
        expect(data["errors"]).to be_empty
      end
    end

    context "with invalid ticket_batch_id" do
      let(:variables) do
        {
          id: "99999",
          input: {
            availableTickets: 100
          }
        }
      end

      it "returns an error" do
        post "/graphql",
          params: { query: mutation, variables: variables }.to_json,
          headers: headers.merge({ "Content-Type" => "application/json" })

        json = JSON.parse(response.body)
        data = json["data"]["updateTicketBatch"]

        expect(data["ticketBatch"]).to be_nil
        expect(data["errors"]).to include("Ticket batch not found")
      end
    end

    context "updating sale dates" do
      let(:variables) do
        {
          id: ticket_batch.id.to_s,
          input: {
            saleStart: 2.days.from_now.iso8601,
            saleEnd: 10.days.from_now.iso8601
          }
        }
      end

      it "updates the sale dates" do
        post "/graphql",
          params: { query: mutation, variables: variables }.to_json,
          headers: headers.merge({ "Content-Type" => "application/json" })

        json = JSON.parse(response.body)
        data = json["data"]["updateTicketBatch"]

        expect(data["ticketBatch"]).to be_present
        expect(data["errors"]).to be_empty

        ticket_batch.reload
        expect(ticket_batch.sale_start).to be_within(1.second).of(2.days.from_now)
        expect(ticket_batch.sale_end).to be_within(1.second).of(10.days.from_now)
      end
    end

    context "with sale_start after sale_end" do
      let(:variables) do
        {
          id: ticket_batch.id.to_s,
          input: {
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
        data = json["data"]["updateTicketBatch"]

        expect(data["ticketBatch"]).to be_nil
        expect(data["errors"]).to be_present
        expect(data["errors"].first).to include("earlier than")
      end
    end

    context "with overlapping sales periods" do
      before do
        create(:ticket_batch,
          event: event,
          sale_start: 15.days.from_now,
          sale_end: 20.days.from_now)
      end

      let(:variables) do
        {
          id: ticket_batch.id.to_s,
          input: {
            saleStart: 14.days.from_now.iso8601,
            saleEnd: 18.days.from_now.iso8601
          }
        }
      end

      it "returns validation error" do
        post "/graphql",
          params: { query: mutation, variables: variables }.to_json,
          headers: headers.merge({ "Content-Type" => "application/json" })

        json = JSON.parse(response.body)
        data = json["data"]["updateTicketBatch"]

        expect(data["ticketBatch"]).to be_nil
        expect(data["errors"].first).to include("conflicts")
      end
    end
  end

  context "when authenticated as regular user" do
    let(:headers) { { "Authorization" => "Bearer #{user_token}" } }
    let(:variables) do
      {
        id: ticket_batch.id.to_s,
        input: {
          availableTickets: 100
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
        id: ticket_batch.id.to_s,
        input: {
          availableTickets: 100
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
