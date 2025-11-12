# frozen_string_literal: true

require "rails_helper"

RSpec.describe Queries::Orders::AllOrders, type: :request do
  describe ".resolve" do
    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }
    let!(:admin) { create(:user, admin: true) }
    let!(:event) { create(:event) }
    let!(:ticket_batch) { create(:ticket_batch, event: event) }

    let!(:user1_orders) { create_list(:order, 2, user: user1, ticket_batch: ticket_batch) }
    let!(:user2_orders) { create_list(:order, 3, user: user2, ticket_batch: ticket_batch) }

    let(:admin_token) { Authentication.encode_token({ user_id: admin.id }) }
    let(:user_token) { Authentication.encode_token({ user_id: user1.id }) }

    let(:query) do
      <<~GRAPHQL
        query($userId: ID) {
          allOrders(userId: $userId) {
            id
            quantity
            totalPrice
            status
            user {
              id
              email
            }
            ticketBatch {
              id
            }
          }
        }
      GRAPHQL
    end

    context "as admin" do
      context "without user_id filter" do
        let(:variables) { {} }

        it "returns all orders" do
          post "/graphql",
               params: { query: query, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          orders = json["data"]["allOrders"]

          expect(orders.length).to eq(5)
        end

        it "orders by created_at desc" do
          newest_order = create(:order, user: user1, ticket_batch: ticket_batch)

          post "/graphql",
               params: { query: query, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          orders = json["data"]["allOrders"]

          expect(orders.first["id"]).to eq(newest_order.id.to_s)
        end

        it "includes user data" do
          post "/graphql",
               params: { query: query, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          orders = json["data"]["allOrders"]

          orders.each do |order|
            expect(order["user"]).to be_present
            expect(order["user"]["email"]).to be_present
          end
        end

        it "includes ticket batch data" do
          post "/graphql",
               params: { query: query, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          orders = json["data"]["allOrders"]

          orders.each do |order|
            expect(order["ticketBatch"]).to be_present
            expect(order["ticketBatch"]["id"]).to eq(ticket_batch.id.to_s)
          end
        end
      end

      context "with user_id filter" do
        let(:variables) { { userId: user1.id.to_s } }

        it "returns only orders for the specified user" do
          post "/graphql",
               params: { query: query, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          orders = json["data"]["allOrders"]

          expect(orders.length).to eq(2)
          orders.each do |order|
            expect(order["user"]["id"]).to eq(user1.id.to_s)
          end
        end

        it "returns empty array when user has no orders" do
          user_without_orders = create(:user)
          variables_no_orders = { userId: user_without_orders.id.to_s }

          post "/graphql",
               params: { query: query, variables: variables_no_orders }.to_json,
               headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          orders = json["data"]["allOrders"]

          expect(orders).to eq([])
        end
      end
    end

    context "as regular user" do
      let(:variables) { {} }

      it "returns an error" do
        post "/graphql",
             params: { query: query, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)

        expect(json["data"]).to be_nil
        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("Admin access required")
      end
    end

    context "without authentication" do
      let(:variables) { {} }

      it "returns an error" do
        post "/graphql", params: { query: query, variables: variables }.to_json, headers: { "Content-Type" => "application/json" }

        json = JSON.parse(response.body)

        expect(json["data"]).to be_nil
        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("You must be logged in to perform this action")
      end
    end

    context "with invalid user_id" do
      let(:variables) { { userId: "99999" } }

      it "returns empty array" do
        post "/graphql",
             params: { query: query, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        orders = json["data"]["allOrders"]

        expect(orders).to eq([])
      end
    end
  end
end
