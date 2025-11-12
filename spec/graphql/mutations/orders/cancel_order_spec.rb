# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Orders::CancelOrder, type: :request do
  describe ".resolve" do
    let!(:user) { create(:user) }
    let!(:admin) { create(:user, admin: true) }
    let!(:other_user) { create(:user) }
    let!(:event) { create(:event) }
    let!(:ticket_batch) { create(:ticket_batch, event: event, available_tickets: 10) }
    let!(:order) do
      create(:order,
             user: user,
             ticket_batch: ticket_batch,
             quantity: 2,
             status: :pending)
    end

    let(:user_token) { Authentication.encode_token({ user_id: user.id }) }
    let(:admin_token) { Authentication.encode_token({ user_id: admin.id }) }
    let(:other_user_token) { Authentication.encode_token({ user_id: other_user.id }) }

    let(:mutation) do
      <<~GRAPHQL
        mutation($input: CancelOrderInput!) {
          cancelOrder(input: $input) {
            order {
              id
              status
              quantity
              ticketBatch {
                availableTickets
              }
            }
            errors
          }
        }
      GRAPHQL
    end

    context "as order owner" do
      let(:variables) do
        {
          input: {
            id: order.id.to_s
          }
        }
      end

      it "cancels the order" do
        post "/graphql",
             params: { query: mutation, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        data = json["data"]["cancelOrder"]

        expect(data["errors"]).to be_empty
        expect(data["order"]["status"]).to eq("cancelled")

        order.reload
        expect(order.status).to eq("cancelled")
      end

      it "restores available tickets" do
        initial_tickets = ticket_batch.available_tickets

        post "/graphql",
             params: { query: mutation, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        data = json["data"]["cancelOrder"]

        expect(data["order"]["ticketBatch"]["availableTickets"]).to eq(initial_tickets + 2)

        ticket_batch.reload
        expect(ticket_batch.available_tickets).to eq(initial_tickets + 2)
      end
    end

    context "as admin" do
      let(:variables) do
        {
          input: {
            id: order.id.to_s
          }
        }
      end

      it "can cancel any order" do
        post "/graphql",
             params: { query: mutation, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        data = json["data"]["cancelOrder"]

        expect(data["errors"]).to be_empty
        expect(data["order"]["status"]).to eq("cancelled")
      end
    end

    context "as different user (not owner)" do
      let(:variables) do
        {
          input: {
            id: order.id.to_s
          }
        }
      end

      it "returns forbidden error" do
        post "/graphql",
             params: { query: mutation, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{other_user_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        data = json["data"]["cancelOrder"]

        expect(data["order"]).to be_nil
        expect(data["errors"]).to include("Forbidden")
      end

      it "does not cancel the order" do
        post "/graphql",
             params: { query: mutation, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{other_user_token}", "Content-Type" => "application/json" }

        order.reload
        expect(order.status).to eq("pending")
      end
    end

    context "when order is already paid" do
      before { order.update!(status: :paid) }

      let(:variables) do
        {
          input: {
            id: order.id.to_s
          }
        }
      end

      it "returns an error" do
        post "/graphql",
             params: { query: mutation, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        data = json["data"]["cancelOrder"]

        expect(data["order"]).to be_nil
        expect(data["errors"]).to include("Invalid status")
      end
    end

    context "when order is already cancelled" do
      before { order.update!(status: :cancelled) }

      let(:variables) do
        {
          input: {
            id: order.id.to_s
          }
        }
      end

      it "returns an error" do
        post "/graphql",
             params: { query: mutation, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        data = json["data"]["cancelOrder"]

        expect(data["order"]).to be_nil
        expect(data["errors"]).to include("Invalid status")
      end
    end

    context "when order does not exist" do
      let(:variables) do
        {
          input: {
            id: "99999"
          }
        }
      end

      it "returns an error" do
        post "/graphql",
             params: { query: mutation, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        data = json["data"]["cancelOrder"]

        expect(data["order"]).to be_nil
        expect(data["errors"]).to include("Order not found")
      end
    end

    context "without authentication" do
      let(:variables) do
        {
          input: {
            id: order.id.to_s
          }
        }
      end

      it "returns an error" do
        post "/graphql", params: { query: mutation, variables: variables }.to_json, headers: { "Content-Type" => "application/json" }

        json = JSON.parse(response.body)

        expect(json["data"]["cancelOrder"]).to be_nil
        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("You must be logged in to perform this action")
      end
    end
  end
end
