# frozen_string_literal: true

require "rails_helper"

RSpec.describe Queries::Users::GetUser, type: :request do
  describe ".resolve" do
    let!(:target_user) { create(:user, first_name: "Jane", last_name: "Smith", email: "jane@example.com") }

    let(:query) do
      <<~GRAPHQL
        query($id: ID!) {
          user(id: $id) {
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

    context "when authenticated as admin" do
      let(:admin_user) { create(:user, admin: true) }
      let(:token) { Authentication.encode_token({ user_id: admin_user.id }) }

      it "returns the requested user data" do
        post "/graphql",
             params: { query: query, variables: { id: target_user.id } },
             headers: { "Authorization" => "Bearer #{token}" }

        json = JSON.parse(response.body)
        data = json["data"]["user"]

        expect(data["id"]).to eq(target_user.id.to_s)
        expect(data["email"]).to eq("jane@example.com")
        expect(data["firstName"]).to eq("Jane")
        expect(data["lastName"]).to eq("Smith")
      end

      it "returns associations when requested" do
        create_list(:order, 2, user: target_user)
        create_list(:ticket, 3, user: target_user)

        query_with_associations = <<~GRAPHQL
          query($id: ID!) {
            user(id: $id) {
              id
              orders {
                id
                status
              }
              tickets {
                id
              }
            }
          }
        GRAPHQL

        post "/graphql",
             params: { query: query_with_associations, variables: { id: target_user.id } },
             headers: { "Authorization" => "Bearer #{token}" }

        json = JSON.parse(response.body)
        data = json["data"]["user"]

        expect(data["orders"].length).to eq(2)
        expect(data["tickets"].length).to eq(3)
      end
    end

    context "when authenticated as non-admin user" do
      let(:regular_user) { create(:user, admin: false) }
      let(:token) { Authentication.encode_token({ user_id: regular_user.id }) }

      it "returns an admin required error" do
        post "/graphql",
             params: { query: query, variables: { id: target_user.id } },
             headers: { "Authorization" => "Bearer #{token}" }

        json = JSON.parse(response.body)

        expect(json["data"]["user"]).to be_nil
        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("Admin access required")
      end
    end

    context "without authentication" do
      it "returns an authentication required error" do
        post "/graphql",
             params: { query: query, variables: { id: target_user.id } }

        json = JSON.parse(response.body)

        expect(json["data"]["user"]).to be_nil
        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("You must be logged in to perform this action")
      end
    end

    context "when user does not exist" do
      let(:admin_user) { create(:user, admin: true) }
      let(:token) { Authentication.encode_token({ user_id: admin_user.id }) }

      it "returns a not found error" do
        post "/graphql",
             params: { query: query, variables: { id: 99999 } },
             headers: { "Authorization" => "Bearer #{token}" }

        json = JSON.parse(response.body)

        expect(json["data"]["user"]).to be_nil
        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("User not found")
      end
    end
  end
end
