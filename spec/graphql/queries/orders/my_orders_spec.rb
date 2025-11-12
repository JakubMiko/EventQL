# frozen_string_literal: true

require "rails_helper"

RSpec.describe Queries::Orders::MyOrders, type: :request do
  describe ".resolve" do
    let!(:user) { create(:user) }
    let!(:other_user) { create(:user) }
    let!(:event) { create(:event) }
    let!(:ticket_batch) { create(:ticket_batch, event: event) }

    let!(:user_orders) do
      create_list(:order, 3, user: user, ticket_batch: ticket_batch)
    end
    let!(:other_user_order) { create(:order, user: other_user, ticket_batch: ticket_batch) }

    let(:token) { Authentication.encode_token({ user_id: user.id }) }

    let(:query) do
      <<~GRAPHQL
        query {
          myOrders {
            id
            quantity
            totalPrice
            status
            user {
              id
            }
            ticketBatch {
              id
            }
            tickets {
              id
            }
          }
        }
      GRAPHQL
    end

    context "when authenticated" do
      it "returns only the current user's orders" do
        post "/graphql",
             params: { query: query }.to_json,
             headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        orders = json["data"]["myOrders"]

        expect(orders.length).to eq(3)
        orders.each do |order|
          expect(order["user"]["id"]).to eq(user.id.to_s)
        end
      end

      it "orders by created_at desc" do
        # Create a new order to ensure ordering
        newest_order = create(:order, user: user, ticket_batch: ticket_batch)

        post "/graphql",
             params: { query: query }.to_json,
             headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        orders = json["data"]["myOrders"]

        expect(orders.first["id"]).to eq(newest_order.id.to_s)
      end

      it "includes associated ticket batch" do
        post "/graphql",
             params: { query: query }.to_json,
             headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        orders = json["data"]["myOrders"]

        orders.each do |order|
          expect(order["ticketBatch"]).to be_present
          expect(order["ticketBatch"]["id"]).to eq(ticket_batch.id.to_s)
        end
      end

      it "includes associated tickets" do
        # Create tickets for one order
        order_with_tickets = user_orders.first
        create_list(:ticket, 2, order: order_with_tickets, user: user, event: event)

        post "/graphql",
             params: { query: query }.to_json,
             headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        orders = json["data"]["myOrders"]

        order_data = orders.find { |o| o["id"] == order_with_tickets.id.to_s }
        expect(order_data["tickets"].length).to eq(2)
      end

      it "returns empty array when user has no orders" do
        user_orders.each(&:destroy)

        post "/graphql",
             params: { query: query }.to_json,
             headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        orders = json["data"]["myOrders"]

        expect(orders).to eq([])
      end
    end

    context "without authentication" do
      it "returns an error" do
        post "/graphql", params: { query: query }.to_json, headers: { "Content-Type" => "application/json" }

        json = JSON.parse(response.body)

        expect(json["data"]).to be_nil
        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("You must be logged in to perform this action")
      end
    end

    context "with invalid token" do
      it "returns an error" do
        post "/graphql",
             params: { query: query }.to_json,
             headers: { "Authorization" => "Bearer invalid_token", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)

        expect(json["data"]).to be_nil
        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("You must be logged in to perform this action")
      end
    end
  end
end
