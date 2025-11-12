# frozen_string_literal: true

require "rails_helper"

RSpec.describe Queries::Tickets::GetTicket, type: :request do
  describe ".resolve" do
    let!(:user) { create(:user) }
    let!(:admin) { create(:user, admin: true) }
    let!(:other_user) { create(:user) }
    let!(:event) { create(:event) }
    let!(:ticket_batch) { create(:ticket_batch, event: event, price: 50.00) }
    let!(:order) { create(:order, user: user, ticket_batch: ticket_batch) }
    let!(:ticket) { create(:ticket, user: user, event: event, order: order, price: 50.00) }

    let(:user_token) { Authentication.encode_token({ user_id: user.id }) }
    let(:admin_token) { Authentication.encode_token({ user_id: admin.id }) }
    let(:other_user_token) { Authentication.encode_token({ user_id: other_user.id }) }

    let(:query) do
      <<~GRAPHQL
        query($id: ID!) {
          ticket(id: $id) {
            id
            ticketNumber
            price
            user {
              id
              email
            }
            event {
              id
              name
            }
            order {
              id
            }
          }
        }
      GRAPHQL
    end

    context "as ticket owner" do
      let(:variables) { { id: ticket.id.to_s } }

      it "returns the ticket" do
        post "/graphql",
             params: { query: query, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        ticket_data = json["data"]["ticket"]

        expect(ticket_data["id"]).to eq(ticket.id.to_s)
        expect(ticket_data["ticketNumber"]).to eq(ticket.ticket_number)
        expect(ticket_data["price"]).to eq(50.0)
      end

      it "includes user data" do
        post "/graphql",
             params: { query: query, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        ticket_data = json["data"]["ticket"]

        expect(ticket_data["user"]["id"]).to eq(user.id.to_s)
        expect(ticket_data["user"]["email"]).to eq(user.email)
      end

      it "includes event data" do
        post "/graphql",
             params: { query: query, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        ticket_data = json["data"]["ticket"]

        expect(ticket_data["event"]["id"]).to eq(event.id.to_s)
        expect(ticket_data["event"]["name"]).to eq(event.name)
      end

      it "includes order data" do
        post "/graphql",
             params: { query: query, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        ticket_data = json["data"]["ticket"]

        expect(ticket_data["order"]["id"]).to eq(order.id.to_s)
      end
    end

    context "as admin" do
      let(:variables) { { id: ticket.id.to_s } }

      it "can view any ticket" do
        post "/graphql",
             params: { query: query, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        ticket_data = json["data"]["ticket"]

        expect(ticket_data["id"]).to eq(ticket.id.to_s)
        expect(ticket_data["user"]["id"]).to eq(user.id.to_s)
      end
    end

    context "as different user (not owner)" do
      let(:variables) { { id: ticket.id.to_s } }

      it "returns an error" do
        post "/graphql",
             params: { query: query, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{other_user_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)

        expect(json["data"]["ticket"]).to be_nil
        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("Forbidden")
      end
    end

    context "when ticket does not exist" do
      let(:variables) { { id: "99999" } }

      it "returns null" do
        post "/graphql",
             params: { query: query, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)

        expect(json["data"]["ticket"]).to be_nil
      end
    end

    context "without authentication" do
      let(:variables) { { id: ticket.id.to_s } }

      it "returns an error" do
        post "/graphql", params: { query: query, variables: variables }.to_json, headers: { "Content-Type" => "application/json" }

        json = JSON.parse(response.body)

        expect(json["data"]["ticket"]).to be_nil
        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("You must be logged in to perform this action")
      end
    end
  end
end
