# frozen_string_literal: true

require "rails_helper"

RSpec.describe Queries::Orders::Show, type: :request do
  describe ".resolve" do
    let!(:user) { create(:user) }
    let!(:admin) { create(:user, admin: true) }
    let!(:other_user) { create(:user) }
    let!(:event) { create(:event) }
    let!(:ticket_batch) { create(:ticket_batch, event: event) }
    let!(:order) do
      create(:order,
             user: user,
             ticket_batch: ticket_batch,
             quantity: 2,
             total_price: 100.00,
             status: :pending)
    end
    let!(:tickets) { create_list(:ticket, 2, order: order, user: user, event: event) }

    let(:user_token) { Authentication.encode_token({ user_id: user.id }) }
    let(:admin_token) { Authentication.encode_token({ user_id: admin.id }) }
    let(:other_user_token) { Authentication.encode_token({ user_id: other_user.id }) }

    let(:query) do
      <<~GRAPHQL
        query($id: ID!) {
          order(id: $id) {
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
              price
            }
            tickets {
              id
              ticketNumber
            }
          }
        }
      GRAPHQL
    end

    context "as order owner" do
      let(:variables) { { id: order.id.to_s } }

      it "returns the order" do
        post "/graphql",
             params: { query: query, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        order_data = json["data"]["order"]

        expect(order_data["id"]).to eq(order.id.to_s)
        expect(order_data["quantity"]).to eq(2)
        expect(order_data["totalPrice"]).to eq(100.0)
        expect(order_data["status"]).to eq("pending")
      end

      it "includes user data" do
        post "/graphql",
             params: { query: query, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        order_data = json["data"]["order"]

        expect(order_data["user"]["id"]).to eq(user.id.to_s)
        expect(order_data["user"]["email"]).to eq(user.email)
      end

      it "includes ticket batch data" do
        post "/graphql",
             params: { query: query, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        order_data = json["data"]["order"]

        expect(order_data["ticketBatch"]["id"]).to eq(ticket_batch.id.to_s)
        expect(order_data["ticketBatch"]["price"]).to be_present
      end

      it "includes tickets" do
        post "/graphql",
             params: { query: query, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        order_data = json["data"]["order"]

        expect(order_data["tickets"].length).to eq(2)
        order_data["tickets"].each do |ticket|
          expect(ticket["ticketNumber"]).to be_present
        end
      end
    end

    context "as admin" do
      let(:variables) { { id: order.id.to_s } }

      it "can view any order" do
        post "/graphql",
             params: { query: query, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        order_data = json["data"]["order"]

        expect(order_data["id"]).to eq(order.id.to_s)
        expect(order_data["user"]["id"]).to eq(user.id.to_s)
      end
    end

    context "as different user (not owner)" do
      let(:variables) { { id: order.id.to_s } }

      it "returns an error" do
        post "/graphql",
             params: { query: query, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{other_user_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)

        expect(json["data"]["order"]).to be_nil
        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("Forbidden")
      end
    end

    context "when order does not exist" do
      let(:variables) { { id: "99999" } }

      it "returns null" do
        post "/graphql",
             params: { query: query, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)

        expect(json["data"]["order"]).to be_nil
      end
    end

    context "without authentication" do
      let(:variables) { { id: order.id.to_s } }

      it "returns an error" do
        post "/graphql", params: { query: query, variables: variables }.to_json, headers: { "Content-Type" => "application/json" }

        json = JSON.parse(response.body)

        expect(json["data"]["order"]).to be_nil
        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("You must be logged in to perform this action")
      end
    end
  end
end
