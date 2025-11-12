# frozen_string_literal: true

require "rails_helper"

RSpec.describe Queries::Users::PublicUser, type: :request do
  describe ".resolve" do
    let!(:user) { create(:user, first_name: "John", last_name: "Doe", email: "john@example.com") }

    let(:query) do
      <<~GRAPHQL
        query($id: ID!) {
          publicUser(id: $id) {
            id
            email
            firstName
            lastName
            createdAt
          }
        }
      GRAPHQL
    end

    context "when user exists" do
      it "returns the public user data" do
        post "/graphql", params: {
          query: query,
          variables: { id: user.id.to_s }
        }

        json = JSON.parse(response.body)
        data = json["data"]["publicUser"]

        expect(response).to have_http_status(:success)
        expect(data["id"]).to eq(user.id.to_s)
        expect(data["email"]).to eq("john@example.com")
        expect(data["firstName"]).to eq("John")
        expect(data["lastName"]).to eq("Doe")
        expect(data["createdAt"]).to be_present
      end

      it "only returns public fields" do
        post "/graphql", params: {
          query: query,
          variables: { id: user.id.to_s }
        }

        json = JSON.parse(response.body)
        data = json["data"]["publicUser"]

        # Should NOT include sensitive fields
        expect(data.keys).not_to include("admin")
        expect(data.keys).not_to include("encryptedPassword")
      end
    end

    context "when user does not exist" do
      it "returns an error" do
        post "/graphql", params: {
          query: query,
          variables: { id: "99999" }
        }

        json = JSON.parse(response.body)

        expect(json["data"]["publicUser"]).to be_nil
        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("User not found")
      end
    end

    context "when client requests only specific fields" do
      let(:minimal_query) do
        <<~GRAPHQL
          query($id: ID!) {
            publicUser(id: $id) {
              email
            }
          }
        GRAPHQL
      end

      it "returns only requested fields" do
        post "/graphql", params: {
          query: minimal_query,
          variables: { id: user.id.to_s }
        }

        json = JSON.parse(response.body)
        data = json["data"]["publicUser"]

        expect(data.keys).to eq([ "email" ])
        expect(data["email"]).to eq("john@example.com")
      end
    end
  end
end
