# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Users::ChangePassword, type: :request do
  describe ".resolve" do
    let!(:user) { create(:user, email: "john@example.com", password: "old_password") }
    let(:token) { Authentication.encode_token({ user_id: user.id }) }

    let(:mutation) do
      <<~GRAPHQL
        mutation($input: ChangePasswordInput!) {
          changePassword(input: $input) {
            success
            message
            errors
          }
        }
      GRAPHQL
    end

    context "when authenticated with valid current password" do
      let(:variables) do
        {
          input: {
            currentPassword: "old_password",
            newPassword: "new_password123",
            newPasswordConfirmation: "new_password123"
          }
        }
      end

      it "changes the password" do
        post "/graphql",
             params: { query: mutation, variables: variables },
             headers: { "Authorization" => "Bearer #{token}" }

        user.reload
        expect(user.valid_password?("new_password123")).to be(true)
        expect(user.valid_password?("old_password")).to be(false)
      end

      it "returns success" do
        post "/graphql",
             params: { query: mutation, variables: variables },
             headers: { "Authorization" => "Bearer #{token}" }

        json = JSON.parse(response.body)
        data = json["data"]["changePassword"]

        expect(data["success"]).to be(true)
        expect(data["message"]).to eq("Password changed successfully")
        expect(data["errors"]).to be_empty
      end
    end

    context "with incorrect current password" do
      let(:variables) do
        {
          input: {
            currentPassword: "wrong_password",
            newPassword: "new_password123",
            newPasswordConfirmation: "new_password123"
          }
        }
      end

      it "does not change the password" do
        post "/graphql",
             params: { query: mutation, variables: variables },
             headers: { "Authorization" => "Bearer #{token}" }

        user.reload
        expect(user.valid_password?("old_password")).to be(true)
      end

      it "returns an error" do
        post "/graphql",
             params: { query: mutation, variables: variables },
             headers: { "Authorization" => "Bearer #{token}" }

        json = JSON.parse(response.body)
        data = json["data"]["changePassword"]

        expect(data["success"]).to be(false)
        expect(data["errors"]).to include("Current password is incorrect")
      end
    end

    context "with mismatched password confirmation" do
      let(:variables) do
        {
          input: {
            currentPassword: "old_password",
            newPassword: "new_password123",
            newPasswordConfirmation: "different_password"
          }
        }
      end

      it "returns an error" do
        post "/graphql",
             params: { query: mutation, variables: variables },
             headers: { "Authorization" => "Bearer #{token}" }

        json = JSON.parse(response.body)
        data = json["data"]["changePassword"]

        expect(data["success"]).to be(false)
        expect(data["errors"]).to include("Password confirmation does not match")
      end
    end

    context "without authentication" do
      let(:variables) do
        {
          input: {
            currentPassword: "old_password",
            newPassword: "new_password123",
            newPasswordConfirmation: "new_password123"
          }
        }
      end

      it "returns an authentication error" do
        post "/graphql", params: { query: mutation, variables: variables }

        json = JSON.parse(response.body)

        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("You must be logged in to perform this action")
      end
    end

    context "with invalid JWT token" do
      let(:variables) do
        {
          input: {
            currentPassword: "old_password",
            newPassword: "new_password123",
            newPasswordConfirmation: "new_password123"
          }
        }
      end

      it "returns an authentication error" do
        post "/graphql",
             params: { query: mutation, variables: variables },
             headers: { "Authorization" => "Bearer invalid_token" }

        json = JSON.parse(response.body)

        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("You must be logged in to perform this action")
      end
    end
  end
end
