# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Orders::PayOrder, type: :request do
  describe ".resolve" do
    let!(:user) { create(:user) }
    let!(:admin) { create(:user, admin: true) }
    let!(:other_user) { create(:user) }
    let!(:event) { create(:event) }
    let!(:ticket_batch) { create(:ticket_batch, event: event, price: 50.00) }
    let!(:order) do
      create(:order,
             user: user,
             ticket_batch: ticket_batch,
             quantity: 2,
             total_price: 100.00,
             status: :pending)
    end

    let(:user_token) { Authentication.encode_token({ user_id: user.id }) }
    let(:admin_token) { Authentication.encode_token({ user_id: admin.id }) }
    let(:other_user_token) { Authentication.encode_token({ user_id: other_user.id }) }

    let(:mutation) do
      <<~GRAPHQL
        mutation($input: PayOrderInput!) {
          payOrder(input: $input) {
            order {
              id
              status
              totalPrice
            }
            errors
          }
        }
      GRAPHQL
    end

    context "as order owner" do
      context "with valid payment" do
        let(:variables) do
          {
            input: {
              id: order.id.to_s
            }
          }
        end

        it "marks the order as paid" do
          post "/graphql",
               params: { query: mutation, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          data = json["data"]["payOrder"]

          expect(data["errors"]).to be_empty
          expect(data["order"]["status"]).to eq("paid")

          order.reload
          expect(order.status).to eq("paid")
        end
      end

      context "with amount verification" do
        let(:variables) do
          {
            input: {
              id: order.id.to_s,
              amount: "100.00"
            }
          }
        end

        it "succeeds when amount matches" do
          post "/graphql",
               params: { query: mutation, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          data = json["data"]["payOrder"]

          expect(data["errors"]).to be_empty
          expect(data["order"]["status"]).to eq("paid")
        end
      end

      context "with incorrect amount" do
        let(:variables) do
          {
            input: {
              id: order.id.to_s,
              amount: "50.00"
            }
          }
        end

        it "returns an error" do
          post "/graphql",
               params: { query: mutation, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          data = json["data"]["payOrder"]

          expect(data["order"]).to be_nil
          expect(data["errors"]).to include("Amount mismatch")

          order.reload
          expect(order.status).to eq("pending")
        end
      end

      context "with payment method card_declined" do
        let(:variables) do
          {
            input: {
              id: order.id.to_s,
              paymentMethod: "card_declined"
            }
          }
        end

        it "returns payment declined error" do
          post "/graphql",
               params: { query: mutation, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          data = json["data"]["payOrder"]

          expect(data["order"]).to be_nil
          expect(data["errors"]).to include("Payment declined")

          order.reload
          expect(order.status).to eq("pending")
        end
      end

      context "with force_payment_status fail" do
        let(:variables) do
          {
            input: {
              id: order.id.to_s,
              forcePaymentStatus: "fail"
            }
          }
        end

        it "returns payment declined error" do
          post "/graphql",
               params: { query: mutation, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          data = json["data"]["payOrder"]

          expect(data["order"]).to be_nil
          expect(data["errors"]).to include("Payment declined")
        end
      end

      context "with force_payment_status success" do
        let(:variables) do
          {
            input: {
              id: order.id.to_s,
              forcePaymentStatus: "success"
            }
          }
        end

        it "marks the order as paid" do
          post "/graphql",
               params: { query: mutation, variables: variables }.to_json,
               headers: { "Authorization" => "Bearer #{user_token}", "Content-Type" => "application/json" }

          json = JSON.parse(response.body)
          data = json["data"]["payOrder"]

          expect(data["errors"]).to be_empty
          expect(data["order"]["status"]).to eq("paid")
        end
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

      it "can pay any order" do
        post "/graphql",
             params: { query: mutation, variables: variables }.to_json,
             headers: { "Authorization" => "Bearer #{admin_token}", "Content-Type" => "application/json" }

        json = JSON.parse(response.body)
        data = json["data"]["payOrder"]

        expect(data["errors"]).to be_empty
        expect(data["order"]["status"]).to eq("paid")
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
        data = json["data"]["payOrder"]

        expect(data["order"]).to be_nil
        expect(data["errors"]).to include("Forbidden")

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
        data = json["data"]["payOrder"]

        expect(data["order"]).to be_nil
        expect(data["errors"]).to include("Invalid status")
      end
    end

    context "when order is cancelled" do
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
        data = json["data"]["payOrder"]

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
        data = json["data"]["payOrder"]

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

        expect(json["data"]["payOrder"]).to be_nil
        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("You must be logged in to perform this action")
      end
    end
  end
end
