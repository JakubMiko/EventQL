# frozen_string_literal: true

require "rails_helper"

RSpec.describe Queries::Tickets::SearchTickets, type: :request do
  describe ".resolve" do
    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }
    let!(:admin) { create(:user, admin: true) }
    let!(:event1) { create(:event, name: "Event 1") }
    let!(:event2) { create(:event, name: "Event 2") }
    let!(:ticket_batch1) { create(:ticket_batch, event: event1, price: 50.00) }
    let!(:ticket_batch2) { create(:ticket_batch, event: event2, price: 100.00) }
    let!(:order1) { create(:order, user: user1, ticket_batch: ticket_batch1) }
    let!(:order2) { create(:order, user: user2, ticket_batch: ticket_batch2) }

    let!(:ticket1) { create(:ticket, user: user1, event: event1, order: order1, price: 50.00) }
    let!(:ticket2) { create(:ticket, user: user1, event: event2, order: order2, price: 100.00) }
    let!(:ticket3) { create(:ticket, user: user2, event: event1, order: order1, price: 50.00) }

    let(:admin_token) { Authentication.encode_token({ user_id: admin.id }) }
    let(:user_token) { Authentication.encode_token({ user_id: user1.id }) }

    let(:query) do
      <<~GRAPHQL
        query($filters: SearchTicketsInput) {
          searchTickets(filters: $filters) {
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

    context "as admin" do
      context "without filters" do
        let(:variables) { {} }

        it "returns all tickets" do
          post "/graphql",
               params: { query: query, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          tickets = json["data"]["searchTickets"]

          expect(tickets.length).to eq(3)
        end

        it "orders by created_at desc by default" do
          newest_ticket = create(:ticket, user: user1, event: event1, order: order1)

          post "/graphql",
               params: { query: query, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          tickets = json["data"]["searchTickets"]

          expect(tickets.first["id"]).to eq(newest_ticket.id.to_s)
        end
      end

      context "with ticket_number filter (exact match)" do
        let(:variables) do
          {
            filters: {
              ticketNumber: ticket1.ticket_number
            }
          }
        end

        it "returns the exact ticket" do
          post "/graphql",
               params: { query: query, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          tickets = json["data"]["searchTickets"]

          expect(tickets.length).to eq(1)
          expect(tickets.first["id"]).to eq(ticket1.id.to_s)
          expect(tickets.first["ticketNumber"]).to eq(ticket1.ticket_number)
        end

        it "returns error when ticket not found" do
          variables_not_found = { filters: { ticketNumber: "NONEXISTENT" } }

          post "/graphql",
               params: { query: query, variables: variables_not_found }.to_json,
               headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)

          expect(json["data"]).to be_nil
          expect(json["errors"]).to be_present
          expect(json["errors"].first["message"]).to eq("Ticket not found")
        end
      end

      context "with user_id filter" do
        let(:variables) do
          {
            filters: {
              userId: user1.id.to_s
            }
          }
        end

        it "returns only tickets for the specified user" do
          post "/graphql",
               params: { query: query, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          tickets = json["data"]["searchTickets"]

          expect(tickets.length).to eq(2)
          tickets.each do |ticket|
            expect(ticket["user"]["id"]).to eq(user1.id.to_s)
          end
        end
      end

      context "with event_id filter" do
        let(:variables) do
          {
            filters: {
              eventId: event1.id.to_s
            }
          }
        end

        it "returns only tickets for the specified event" do
          post "/graphql",
               params: { query: query, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          tickets = json["data"]["searchTickets"]

          expect(tickets.length).to eq(2)
          tickets.each do |ticket|
            expect(ticket["event"]["id"]).to eq(event1.id.to_s)
          end
        end
      end

      context "with order_id filter" do
        let(:variables) do
          {
            filters: {
              orderId: order1.id.to_s
            }
          }
        end

        it "returns only tickets for the specified order" do
          post "/graphql",
               params: { query: query, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          tickets = json["data"]["searchTickets"]

          expect(tickets.length).to eq(2)
          tickets.each do |ticket|
            expect(ticket["order"]["id"]).to eq(order1.id.to_s)
          end
        end
      end

      context "with price range filters" do
        context "with min_price" do
          let(:variables) do
            {
              filters: {
                minPrice: "75.00"
              }
            }
          end

          it "returns only tickets with price >= min_price" do
            post "/graphql",
                 params: { query: query, variables: variables }.to_json,
                 headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

            json = JSON.parse(response.body)
            tickets = json["data"]["searchTickets"]

            expect(tickets.length).to eq(1)
            expect(tickets.first["id"]).to eq(ticket2.id.to_s)
            expect(tickets.first["price"]).to eq(100.0)
          end
        end

        context "with max_price" do
          let(:variables) do
            {
              filters: {
                maxPrice: "60.00"
              }
            }
          end

          it "returns only tickets with price <= max_price" do
            post "/graphql",
                 params: { query: query, variables: variables }.to_json,
                 headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

            json = JSON.parse(response.body)
            tickets = json["data"]["searchTickets"]

            expect(tickets.length).to eq(2)
            tickets.each do |ticket|
              expect(ticket["price"]).to be <= 60.0
            end
          end
        end

        context "with both min_price and max_price" do
          let(:variables) do
            {
              filters: {
                minPrice: "40.00",
                maxPrice: "60.00"
              }
            }
          end

          it "returns only tickets within price range" do
            post "/graphql",
                 params: { query: query, variables: variables }.to_json,
                 headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

            json = JSON.parse(response.body)
            tickets = json["data"]["searchTickets"]

            expect(tickets.length).to eq(2)
            tickets.each do |ticket|
              expect(ticket["price"]).to be_between(40.0, 60.0)
            end
          end
        end
      end

      context "with sort order" do
        context "with ASC sort" do
          let(:variables) do
            {
              filters: {
                sort: "ASC"
              }
            }
          end

          it "returns tickets in ascending order" do
            post "/graphql",
                 params: { query: query, variables: variables }.to_json,
                 headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

            json = JSON.parse(response.body)
            tickets = json["data"]["searchTickets"]

            expect(tickets.first["id"]).to eq(ticket1.id.to_s)
            expect(tickets.last["id"]).to eq(ticket3.id.to_s)
          end
        end

        context "with DESC sort" do
          let(:variables) do
            {
              filters: {
                sort: "DESC"
              }
            }
          end

          it "returns tickets in descending order" do
            post "/graphql",
                 params: { query: query, variables: variables }.to_json,
                 headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

            json = JSON.parse(response.body)
            tickets = json["data"]["searchTickets"]

            expect(tickets.first["id"]).to eq(ticket3.id.to_s)
            expect(tickets.last["id"]).to eq(ticket1.id.to_s)
          end
        end
      end

      context "with multiple filters combined" do
        let(:variables) do
          {
            filters: {
              userId: user1.id.to_s,
              minPrice: "40.00",
              sort: "ASC"
            }
          }
        end

        it "applies all filters correctly" do
          post "/graphql",
               params: { query: query, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          tickets = json["data"]["searchTickets"]

          expect(tickets.length).to eq(2)
          tickets.each do |ticket|
            expect(ticket["user"]["id"]).to eq(user1.id.to_s)
            expect(ticket["price"]).to be >= 40.0
          end
          # Check order
          expect(tickets.first["id"]).to eq(ticket1.id.to_s)
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
  end
end
