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
            edges {
              node {
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

    context "when authenticated" do
      it "returns only the current user's orders" do
        post "/graphql",
             params: { query: query }.to_json,
             headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        data = json["data"]["myOrders"]
        orders = data["edges"].map { |edge| edge["node"] }

        expect(data["totalCount"]).to eq(3)
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
        data = json["data"]["myOrders"]
        orders = data["edges"].map { |edge| edge["node"] }

        expect(orders.first["id"]).to eq(newest_order.id.to_s)
      end

      it "includes associated ticket batch" do
        post "/graphql",
             params: { query: query }.to_json,
             headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        data = json["data"]["myOrders"]
        orders = data["edges"].map { |edge| edge["node"] }

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
        data = json["data"]["myOrders"]
        orders = data["edges"].map { |edge| edge["node"] }

        order_data = orders.find { |o| o["id"] == order_with_tickets.id.to_s }
        expect(order_data["tickets"].length).to eq(2)
      end

      it "returns empty array when user has no orders" do
        user_orders.each(&:destroy)

        post "/graphql",
             params: { query: query }.to_json,
             headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        data = json["data"]["myOrders"]

        expect(data["edges"]).to eq([])
        expect(data["totalCount"]).to eq(0)
      end
    end

    context "pagination" do
      let!(:pagination_user) { create(:user) }
      let!(:pagination_event) { create(:event) }
      let!(:pagination_ticket_batch) { create(:ticket_batch, event: pagination_event) }
      let(:pagination_token) { Authentication.encode_token({ user_id: pagination_user.id }) }

      before do
        # Create 25 orders to test pagination
        create_list(:order, 25, user: pagination_user, ticket_batch: pagination_ticket_batch)
      end

      it "returns default page size of 20 orders" do
        query = <<~GRAPHQL
          query {
            myOrders {
              edges {
                node {
                  id
                }
              }
              totalCount
              pageInfo {
                hasNextPage
                hasPreviousPage
              }
            }
          }
        GRAPHQL

        post "/graphql",
             params: { query: query }.to_json,
             headers: { "Authorization" => "Bearer #{pagination_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        data = json["data"]["myOrders"]

        expect(data["edges"].length).to eq(20)
        expect(data["totalCount"]).to eq(25)
        expect(data["pageInfo"]["hasNextPage"]).to eq(true)
        expect(data["pageInfo"]["hasPreviousPage"]).to eq(false)
      end

      it "supports custom page size with first argument" do
        query = <<~GRAPHQL
          query {
            myOrders(first: 10) {
              edges {
                node {
                  id
                }
              }
              totalCount
              pageInfo {
                hasNextPage
              }
            }
          }
        GRAPHQL

        post "/graphql",
             params: { query: query }.to_json,
             headers: { "Authorization" => "Bearer #{pagination_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        data = json["data"]["myOrders"]

        expect(data["edges"].length).to eq(10)
        expect(data["totalCount"]).to eq(25)
        expect(data["pageInfo"]["hasNextPage"]).to eq(true)
      end

      it "supports cursor-based pagination with after argument" do
        # First request to get the cursor
        first_query = <<~GRAPHQL
          query {
            myOrders(first: 10) {
              edges {
                cursor
                node {
                  id
                }
              }
              pageInfo {
                endCursor
                hasNextPage
              }
            }
          }
        GRAPHQL

        post "/graphql",
             params: { query: first_query }.to_json,
             headers: { "Authorization" => "Bearer #{pagination_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        data = json["data"]["myOrders"]
        end_cursor = data["pageInfo"]["endCursor"]
        first_page_last_id = data["edges"].last["node"]["id"]

        # Second request with after cursor
        second_query = <<~GRAPHQL
          query {
            myOrders(first: 10, after: "#{end_cursor}") {
              edges {
                node {
                  id
                }
              }
              pageInfo {
                hasPreviousPage
                hasNextPage
              }
            }
          }
        GRAPHQL

        post "/graphql",
             params: { query: second_query }.to_json,
             headers: { "Authorization" => "Bearer #{pagination_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        data = json["data"]["myOrders"]

        expect(data["edges"].length).to eq(10)
        expect(data["edges"].first["node"]["id"]).not_to eq(first_page_last_id)
        expect(data["pageInfo"]["hasPreviousPage"]).to eq(true)
        expect(data["pageInfo"]["hasNextPage"]).to eq(true)
      end

      it "respects max page size of 100" do
        query = <<~GRAPHQL
          query {
            myOrders(first: 150) {
              edges {
                node {
                  id
                }
              }
            }
          }
        GRAPHQL

        post "/graphql",
             params: { query: query }.to_json,
             headers: { "Authorization" => "Bearer #{pagination_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        # GraphQL should limit to max_page_size of 100
        expect(json["data"]["myOrders"]["edges"].length).to be <= 100
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
