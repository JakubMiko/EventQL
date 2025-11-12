# frozen_string_literal: true

require "rails_helper"

RSpec.describe Queries::Users::CurrentUser, type: :request do
  describe ".resolve" do
    let!(:user) { create(:user, first_name: "John", last_name: "Doe", email: "john@example.com", admin: false) }
    let(:token) { Authentication.encode_token({ user_id: user.id }) }

    let(:query) do
      <<~GRAPHQL
        query {
          currentUser {
            id
            email
            firstName
            lastName
            admin
            createdAt
          }
        }
      GRAPHQL
    end

    context "when authenticated" do
      it "returns the current user data" do
        post "/graphql",
             params: { query: query },
             headers: { "Authorization" => "Bearer #{token}" }

        json = JSON.parse(response.body)
        data = json["data"]["currentUser"]

        expect(data["id"]).to eq(user.id.to_s)
        expect(data["email"]).to eq("john@example.com")
        expect(data["firstName"]).to eq("John")
        expect(data["lastName"]).to eq("Doe")
        expect(data["admin"]).to be(false)
        expect(data["createdAt"]).to be_present
      end

      it "returns associations when requested" do
        # Create some orders and tickets for the user
        create_list(:order, 2, user: user)
        create_list(:ticket, 3, user: user)

        query_with_associations = <<~GRAPHQL
          query {
            currentUser {
              id
              email
              orders {
                id
              }
              tickets {
                id
              }
            }
          }
        GRAPHQL

        post "/graphql",
             params: { query: query_with_associations },
             headers: { "Authorization" => "Bearer #{token}" }

        json = JSON.parse(response.body)
        data = json["data"]["currentUser"]

        expect(data["orders"].length).to eq(2)
        expect(data["tickets"].length).to eq(3)
      end
    end

    context "without authentication" do
      it "returns an error" do
        post "/graphql", params: { query: query }

        json = JSON.parse(response.body)

        expect(json["data"]["currentUser"]).to be_nil
        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("You must be logged in to perform this action")
      end
    end

    context "with invalid token" do
      it "returns an error" do
        post "/graphql",
             params: { query: query },
             headers: { "Authorization" => "Bearer invalid_token" }

        json = JSON.parse(response.body)

        expect(json["data"]["currentUser"]).to be_nil
        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("You must be logged in to perform this action")
      end
    end

    context "with expired token" do
      let(:expired_token) do
        payload = { user_id: user.id, exp: 1.hour.ago.to_i }
        JWT.encode(payload, Rails.application.credentials.secret_key_base)
      end

      it "returns an error" do
        post "/graphql",
             params: { query: query },
             headers: { "Authorization" => "Bearer #{expired_token}" }

        json = JSON.parse(response.body)

        expect(json["data"]["currentUser"]).to be_nil
        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("You must be logged in to perform this action")
      end
    end
  end
end
