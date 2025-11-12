# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Users::Login, type: :request do
  describe ".resolve" do
    let!(:user) { create(:user, email: "john@example.com", password: "password123") }

    let(:mutation) do
      <<~GRAPHQL
        mutation($input: LoginInput!) {
          login(input: $input) {
            token
            user {
              id
              email
              firstName
              lastName
            }
            errors
          }
        }
      GRAPHQL
    end

    context "with valid credentials" do
      let(:variables) do
        {
          input: {
            email: "john@example.com",
            password: "password123"
          }
        }
      end

      it "returns a JWT token" do
        post "/graphql", params: { query: mutation, variables: variables }

        json = JSON.parse(response.body)
        data = json["data"]["login"]

        expect(data["token"]).to be_present
        expect(data["errors"]).to be_empty
      end

      it "returns the user data" do
        post "/graphql", params: { query: mutation, variables: variables }

        json = JSON.parse(response.body)
        user_data = json["data"]["login"]["user"]

        expect(user_data["id"]).to eq(user.id.to_s)
        expect(user_data["email"]).to eq("john@example.com")
      end

      it "returns a valid JWT token" do
        post "/graphql", params: { query: mutation, variables: variables }

        json = JSON.parse(response.body)
        token = json["data"]["login"]["token"]

        decoded = Authentication.decode_token(token)
        expect(decoded[:user_id]).to eq(user.id)
      end
    end

    context "with invalid email" do
      let(:variables) do
        {
          input: {
            email: "wrong@example.com",
            password: "password123"
          }
        }
      end

      it "returns an error" do
        post "/graphql", params: { query: mutation, variables: variables }

        json = JSON.parse(response.body)
        data = json["data"]["login"]

        expect(data["token"]).to be_nil
        expect(data["user"]).to be_nil
        expect(data["errors"]).to include("Invalid email or password")
      end
    end

    context "with invalid password" do
      let(:variables) do
        {
          input: {
            email: "john@example.com",
            password: "wrong_password"
          }
        }
      end

      it "returns an error" do
        post "/graphql", params: { query: mutation, variables: variables }

        json = JSON.parse(response.body)
        data = json["data"]["login"]

        expect(data["token"]).to be_nil
        expect(data["user"]).to be_nil
        expect(data["errors"]).to include("Invalid email or password")
      end
    end

    context "when user does not exist" do
      let(:variables) do
        {
          input: {
            email: "nonexistent@example.com",
            password: "password123"
          }
        }
      end

      it "returns an error" do
        post "/graphql", params: { query: mutation, variables: variables }

        json = JSON.parse(response.body)
        data = json["data"]["login"]

        expect(data["errors"]).to include("Invalid email or password")
      end
    end
  end
end
