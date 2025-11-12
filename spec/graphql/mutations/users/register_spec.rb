# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Users::Register, type: :request do
  describe ".resolve" do
    let(:mutation) do
      <<~GRAPHQL
        mutation($input: RegisterInput!) {
          register(input: $input) {
            token
            user {
              id
              email
              firstName
              lastName
              admin
            }
            errors
          }
        }
      GRAPHQL
    end

    context "with valid parameters" do
      let(:variables) do
        {
          input: {
            firstName: "John",
            lastName: "Doe",
            email: "john@example.com",
            password: "password123",
            passwordConfirmation: "password123"
          }
        }
      end

      it "creates a new user" do
        expect {
          post "/graphql", params: { query: mutation, variables: variables }
        }.to change(User, :count).by(1)

        user = User.last
        expect(user.email).to eq("john@example.com")
        expect(user.first_name).to eq("John")
        expect(user.last_name).to eq("Doe")
        expect(user.admin).to be(false)
      end

      it "returns a JWT token" do
        post "/graphql", params: { query: mutation, variables: variables }

        json = JSON.parse(response.body)
        data = json["data"]["register"]

        expect(data["token"]).to be_present
        expect(data["errors"]).to be_empty
      end

      it "returns the user data" do
        post "/graphql", params: { query: mutation, variables: variables }

        json = JSON.parse(response.body)
        user_data = json["data"]["register"]["user"]

        expect(user_data["email"]).to eq("john@example.com")
        expect(user_data["firstName"]).to eq("John")
        expect(user_data["lastName"]).to eq("Doe")
        expect(user_data["admin"]).to be(false)
      end

      it "returns a valid JWT token that can be decoded" do
        post "/graphql", params: { query: mutation, variables: variables }

        json = JSON.parse(response.body)
        token = json["data"]["register"]["token"]

        decoded = Authentication.decode_token(token)
        expect(decoded[:user_id]).to eq(User.last.id)
      end
    end

    context "with invalid email" do
      let(:variables) do
        {
          input: {
            firstName: "John",
            lastName: "Doe",
            email: "invalid_email",
            password: "password123",
            passwordConfirmation: "password123"
          }
        }
      end

      it "does not create a user" do
        expect {
          post "/graphql", params: { query: mutation, variables: variables }
        }.not_to change(User, :count)
      end

      it "returns validation errors" do
        post "/graphql", params: { query: mutation, variables: variables }

        json = JSON.parse(response.body)
        data = json["data"]["register"]

        expect(data["token"]).to be_nil
        expect(data["user"]).to be_nil
        expect(data["errors"]).to include(match(/Email is invalid/))
      end
    end

    context "with mismatched password confirmation" do
      let(:variables) do
        {
          input: {
            firstName: "John",
            lastName: "Doe",
            email: "john@example.com",
            password: "password123",
            passwordConfirmation: "different_password"
          }
        }
      end

      it "returns validation errors" do
        post "/graphql", params: { query: mutation, variables: variables }

        json = JSON.parse(response.body)
        data = json["data"]["register"]

        expect(data["errors"]).to include(match(/Password confirmation doesn't match/))
      end
    end

    context "with duplicate email" do
      before do
        create(:user, email: "john@example.com")
      end

      let(:variables) do
        {
          input: {
            firstName: "John",
            lastName: "Doe",
            email: "john@example.com",
            password: "password123",
            passwordConfirmation: "password123"
          }
        }
      end

      it "returns validation errors" do
        post "/graphql", params: { query: mutation, variables: variables }

        json = JSON.parse(response.body)
        data = json["data"]["register"]

        expect(data["errors"]).to include(match(/Email has already been taken/))
      end
    end

    context "with missing required fields" do
      let(:variables) do
        {
          input: {
            email: "john@example.com",
            password: "password123",
            passwordConfirmation: "password123"
          }
        }
      end

      it "returns GraphQL validation error" do
        post "/graphql", params: { query: mutation, variables: variables }

        json = JSON.parse(response.body)

        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to include("firstName")
        expect(json["errors"].first["message"]).to include("Expected value to not be null")
      end
    end
  end
end
