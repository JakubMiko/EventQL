# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Orders::Create, type: :request do
  describe ".resolve" do
    let!(:user) { create(:user) }
    let!(:event) { create(:event) }
    let!(:ticket_batch) do
      create(:ticket_batch,
             event: event,
             available_tickets: 10,
             price: 50.00,
             sale_start: 1.day.ago,
             sale_end: 1.day.from_now)
    end
    let(:token) { Authentication.encode_token({ user_id: user.id }) }

    let(:mutation) do
      <<~GRAPHQL
        mutation($input: CreateOrderInput!) {
          createOrder(input: $input) {
            order {
              id
              quantity
              totalPrice
              status
              tickets {
                id
                ticketNumber
                price
              }
              ticketBatch {
                id
              }
              user {
                id
              }
            }
            errors
          }
        }
      GRAPHQL
    end

    context "when authenticated" do
      context "with valid parameters" do
        let(:variables) do
          {
            input: {
              ticketBatchId: ticket_batch.id.to_s,
              quantity: 2
            }
          }
        end

        it "creates an order" do
          expect do
            post "/graphql",
                 params: { query: mutation, variables: variables }.to_json,
                 headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
          end.to change(Order, :count).by(1)

          json = JSON.parse(response.body)
          data = json["data"]["createOrder"]

          expect(data["errors"]).to be_empty
          expect(data["order"]).to be_present
          expect(data["order"]["quantity"]).to eq(2)
          expect(data["order"]["totalPrice"]).to eq(100.0)
          expect(data["order"]["status"]).to eq("pending")
        end

        it "creates tickets for the order" do
          expect do
            post "/graphql",
                 params: { query: mutation, variables: variables }.to_json,
                 headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
          end.to change(Ticket, :count).by(2)

          json = JSON.parse(response.body)
          tickets = json["data"]["createOrder"]["order"]["tickets"]

          expect(tickets.length).to eq(2)
          tickets.each do |ticket|
            expect(ticket["ticketNumber"]).to be_present
            expect(ticket["price"]).to eq(50.0)
          end
        end

        it "decrements available tickets" do
          post "/graphql",
               params: { query: mutation, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

          ticket_batch.reload
          expect(ticket_batch.available_tickets).to eq(8)
        end

        it "returns the order with associations" do
          post "/graphql",
               params: { query: mutation, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          order_data = json["data"]["createOrder"]["order"]

          expect(order_data["user"]["id"]).to eq(user.id.to_s)
          expect(order_data["ticketBatch"]["id"]).to eq(ticket_batch.id.to_s)
        end
      end

      context "when requesting more tickets than available" do
        let(:variables) do
          {
            input: {
              ticketBatchId: ticket_batch.id.to_s,
              quantity: 15
            }
          }
        end

        it "returns an error" do
          post "/graphql",
               params: { query: mutation, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          data = json["data"]["createOrder"]

          expect(data["order"]).to be_nil
          expect(data["errors"]).to include(match(/greater than available tickets/))
        end

        it "does not create an order" do
          expect do
            post "/graphql",
                 params: { query: mutation, variables: variables }.to_json,
                 headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
          end.not_to change(Order, :count)
        end
      end

      context "with invalid quantity" do
        let(:variables) do
          {
            input: {
              ticketBatchId: ticket_batch.id.to_s,
              quantity: 0
            }
          }
        end

        it "returns an error" do
          post "/graphql",
               params: { query: mutation, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          data = json["data"]["createOrder"]

          expect(data["order"]).to be_nil
          expect(data["errors"]).to be_present
        end
      end

      context "when sales window is closed" do
        before do
          ticket_batch.update!(sale_start: 2.days.ago, sale_end: 1.day.ago)
        end

        let(:variables) do
          {
            input: {
              ticketBatchId: ticket_batch.id.to_s,
              quantity: 2
            }
          }
        end

        it "returns an error" do
          post "/graphql",
               params: { query: mutation, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          data = json["data"]["createOrder"]

          expect(data["order"]).to be_nil
          expect(data["errors"]).to include(match(/Sales window closed/))
        end
      end

      context "when ticket batch does not exist" do
        let(:variables) do
          {
            input: {
              ticketBatchId: "99999",
              quantity: 2
            }
          }
        end

        it "returns an error" do
          post "/graphql",
               params: { query: mutation, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          data = json["data"]["createOrder"]

          expect(data["order"]).to be_nil
          expect(data["errors"]).to include("Ticket batch not found")
        end
      end
    end

    context "without authentication" do
      let(:variables) do
        {
          input: {
            ticketBatchId: ticket_batch.id.to_s,
            quantity: 2
          }
        }
      end

      it "returns an error" do
        post "/graphql", params: { query: mutation, variables: variables }.to_json, headers: { "Content-Type" => "application/json" }

        json = JSON.parse(response.body)

        expect(json["data"]["createOrder"]).to be_nil
        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("You must be logged in to perform this action")
      end
    end
  end
end
