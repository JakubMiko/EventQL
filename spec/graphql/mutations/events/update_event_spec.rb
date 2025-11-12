# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Events::UpdateEvent, type: :request do
  describe ".resolve" do
    let!(:admin) { create(:user, admin: true, email: "admin@example.com", password: "password123") }
    let!(:regular_user) { create(:user, admin: false, email: "user@example.com", password: "password123") }
    let!(:event) { create(:event, name: "Original Event", category: "music", date: 1.month.from_now) }
    let(:admin_token) { Authentication.encode_token({ user_id: admin.id }) }
    let(:user_token) { Authentication.encode_token({ user_id: regular_user.id }) }

    let(:mutation) do
      <<~GRAPHQL
        mutation UpdateEvent($id: ID!, $input: UpdateEventInput!) {
          updateEvent(id: $id, input: $input) {
            event {
              id
              name
              description
              place
              date
              category
            }
            errors
          }
        }
      GRAPHQL
    end

    context "when authenticated as admin" do
      let(:headers) { { "Authorization" => "Bearer #{admin_token}" } }

      context "with valid parameters" do
        let(:variables) do
          {
            id: event.id,
            input: {
              name: "Updated Event Name",
              description: "Updated description"
            }
          }
        end

        it "updates the event" do
          post "/graphql", params: { query: mutation, variables: variables }, headers: headers

          event.reload
          expect(event.name).to eq("Updated Event Name")
          expect(event.description).to eq("Updated description")
        end

        it "returns the updated event" do
          post "/graphql", params: { query: mutation, variables: variables }, headers: headers

          json = JSON.parse(response.body)
          data = json["data"]["updateEvent"]

          expect(data["event"]).to be_present
          expect(data["event"]["name"]).to eq("Updated Event Name")
          expect(data["event"]["description"]).to eq("Updated description")
          expect(data["errors"]).to be_empty
        end

        it "does not change unspecified fields" do
          original_category = event.category
          original_place = event.place

          post "/graphql", params: { query: mutation, variables: variables }, headers: headers

          event.reload
          expect(event.category).to eq(original_category)
          expect(event.place).to eq(original_place)
        end
      end

      context "updating only the date" do
        let(:new_date) { 2.months.from_now }
        let(:variables) do
          {
            id: event.id,
            input: {
              date: new_date.iso8601
            }
          }
        end

        it "updates only the date" do
          original_name = event.name

          post "/graphql", params: { query: mutation, variables: variables }, headers: headers

          event.reload
          expect(event.date.to_i).to be_within(1).of(new_date.to_i)
          expect(event.name).to eq(original_name)
        end
      end

      context "with invalid date (in the past)" do
        let(:variables) do
          {
            id: event.id,
            input: {
              date: 1.day.ago.iso8601
            }
          }
        end

        it "does not update the event" do
          original_date = event.date

          post "/graphql", params: { query: mutation, variables: variables }, headers: headers

          event.reload
          expect(event.date.to_i).to eq(original_date.to_i)
        end

        it "returns validation errors" do
          post "/graphql", params: { query: mutation, variables: variables }, headers: headers

          json = JSON.parse(response.body)
          data = json["data"]["updateEvent"]

          expect(data["event"]).to be_nil
          expect(data["errors"]).to be_present
          expect(data["errors"].first).to include("must be in the future")
        end
      end

      context "with invalid category" do
        let(:variables) do
          {
            id: event.id,
            input: {
              category: "invalid_category"
            }
          }
        end

        it "returns validation errors" do
          post "/graphql", params: { query: mutation, variables: variables }, headers: headers

          json = JSON.parse(response.body)
          data = json["data"]["updateEvent"]

          expect(data["event"]).to be_nil
          expect(data["errors"]).to be_present
          expect(data["errors"].first).to include("must be one of")
        end
      end

      context "when event does not exist" do
        let(:variables) do
          {
            id: 99999,
            input: {
              name: "New Name"
            }
          }
        end

        it "returns an error" do
          post "/graphql", params: { query: mutation, variables: variables }, headers: headers

          json = JSON.parse(response.body)
          data = json["data"]["updateEvent"]

          expect(data["event"]).to be_nil
          expect(data["errors"]).to eq([ "Event not found" ])
        end
      end
    end

    context "when authenticated as regular user (non-admin)" do
      let(:headers) { { "Authorization" => "Bearer #{user_token}" } }
      let(:variables) do
        {
          id: event.id,
          input: {
            name: "Updated Name"
          }
        }
      end

      it "returns an authorization error" do
        post "/graphql", params: { query: mutation, variables: variables }, headers: headers

        json = JSON.parse(response.body)

        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("Admin access required")
      end

      it "does not update the event" do
        original_name = event.name

        post "/graphql", params: { query: mutation, variables: variables }, headers: headers

        event.reload
        expect(event.name).to eq(original_name)
      end
    end

    context "when not authenticated" do
      let(:variables) do
        {
          id: event.id,
          input: {
            name: "Updated Name"
          }
        }
      end

      it "returns an authentication error" do
        post "/graphql", params: { query: mutation, variables: variables }

        json = JSON.parse(response.body)

        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("You must be logged in to perform this action")
      end

      it "does not update the event" do
        original_name = event.name

        post "/graphql", params: { query: mutation, variables: variables }

        event.reload
        expect(event.name).to eq(original_name)
      end
    end
  end
end
