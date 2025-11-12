# frozen_string_literal: true

require "rails_helper"

RSpec.describe Queries::Tickets::MyTickets, type: :request do
  describe ".resolve" do
    let!(:user) { create(:user) }
    let!(:other_user) { create(:user) }
    let!(:event) { create(:event) }
    let!(:ticket_batch) { create(:ticket_batch, event: event) }
    let!(:order) { create(:order, user: user, ticket_batch: ticket_batch) }
    let!(:other_order) { create(:order, user: other_user, ticket_batch: ticket_batch) }

    let!(:user_tickets) do
      create_list(:ticket, 3, user: user, event: event, order: order)
    end
    let!(:other_user_ticket) { create(:ticket, user: other_user, event: event, order: other_order) }

    let(:token) { Authentication.encode_token({ user_id: user.id }) }

    let(:query) do
      <<~GRAPHQL
        query {
          myTickets {
            id
            ticketNumber
            price
            user {
              id
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

    context "when authenticated" do
      it "returns only the current user's tickets" do
        post "/graphql",
             params: { query: query }.to_json,
             headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        tickets = json["data"]["myTickets"]

        expect(tickets.length).to eq(3)
        tickets.each do |ticket|
          expect(ticket["user"]["id"]).to eq(user.id.to_s)
        end
      end

      it "orders by created_at desc" do
        # Create a new ticket to ensure ordering
        newest_ticket = create(:ticket, user: user, event: event, order: order)

        post "/graphql",
             params: { query: query }.to_json,
             headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        tickets = json["data"]["myTickets"]

        expect(tickets.first["id"]).to eq(newest_ticket.id.to_s)
      end

      it "includes associated event" do
        post "/graphql",
             params: { query: query }.to_json,
             headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        tickets = json["data"]["myTickets"]

        tickets.each do |ticket|
          expect(ticket["event"]).to be_present
          expect(ticket["event"]["id"]).to eq(event.id.to_s)
          expect(ticket["event"]["name"]).to be_present
        end
      end

      it "includes associated order" do
        post "/graphql",
             params: { query: query }.to_json,
             headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        tickets = json["data"]["myTickets"]

        tickets.each do |ticket|
          expect(ticket["order"]).to be_present
          expect(ticket["order"]["id"]).to eq(order.id.to_s)
        end
      end

      it "includes ticket number and price" do
        post "/graphql",
             params: { query: query }.to_json,
             headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        tickets = json["data"]["myTickets"]

        tickets.each do |ticket|
          expect(ticket["ticketNumber"]).to be_present
          expect(ticket["price"]).to be_a(Numeric)
        end
      end

      it "returns empty array when user has no tickets" do
        user_tickets.each(&:destroy)

        post "/graphql",
             params: { query: query }.to_json,
             headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        tickets = json["data"]["myTickets"]

        expect(tickets).to eq([])
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
