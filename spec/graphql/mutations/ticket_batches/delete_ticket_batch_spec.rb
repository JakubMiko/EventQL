# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::TicketBatches::DeleteTicketBatch, type: :request do
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
      mutation DeleteTicketBatch($id: ID!) {
        deleteTicketBatch(id: $id) {
          success
          errors
        }
      }
    GRAPHQL
  end

  context "when authenticated as admin" do
    let(:headers) { { "Authorization" => "Bearer #{admin_token}" } }

    context "with valid ticket_batch_id" do
      let(:variables) { { id: ticket_batch.id.to_s } }

      it "deletes the ticket batch" do
        expect do
          post "/graphql",
            params: { query: mutation, variables: variables }.to_json,
            headers: headers.merge({ "Content-Type" => "application/json" })
        end.to change(TicketBatch, :count).by(-1)
      end

      it "returns success" do
        post "/graphql",
          params: { query: mutation, variables: variables }.to_json,
          headers: headers.merge({ "Content-Type" => "application/json" })

        json = JSON.parse(response.body)
        data = json["data"]["deleteTicketBatch"]

        expect(data["success"]).to be true
        expect(data["errors"]).to be_empty
      end
    end

    context "with invalid ticket_batch_id" do
      let(:variables) { { id: "99999" } }

      it "does not delete any ticket batch" do
        expect do
          post "/graphql",
            params: { query: mutation, variables: variables }.to_json,
            headers: headers.merge({ "Content-Type" => "application/json" })
        end.not_to change(TicketBatch, :count)
      end

      it "returns an error" do
        post "/graphql",
          params: { query: mutation, variables: variables }.to_json,
          headers: headers.merge({ "Content-Type" => "application/json" })

        json = JSON.parse(response.body)
        data = json["data"]["deleteTicketBatch"]

        expect(data["success"]).to be false
        expect(data["errors"]).to include("Ticket batch not found")
      end
    end
  end

  context "when authenticated as regular user" do
    let(:headers) { { "Authorization" => "Bearer #{user_token}" } }
    let(:variables) { { id: ticket_batch.id.to_s } }

    it "does not delete the ticket batch" do
      expect do
        post "/graphql",
          params: { query: mutation, variables: variables }.to_json,
          headers: headers.merge({ "Content-Type" => "application/json" })
      end.not_to change(TicketBatch, :count)
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
    let(:variables) { { id: ticket_batch.id.to_s } }

    it "does not delete the ticket batch" do
      expect do
        post "/graphql",
          params: { query: mutation, variables: variables }.to_json,
          headers: { "Content-Type" => "application/json" }
      end.not_to change(TicketBatch, :count)
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
