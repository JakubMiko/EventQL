# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Events::Create, type: :request do
  describe ".resolve" do
    let!(:admin) { create(:user, admin: true, email: "admin@example.com", password: "password123") }
    let!(:regular_user) { create(:user, admin: false, email: "user@example.com", password: "password123") }
    let(:admin_token) { Authentication.encode_token({ user_id: admin.id }) }
    let(:user_token) { Authentication.encode_token({ user_id: regular_user.id }) }

    let(:mutation) do
      <<~GRAPHQL
        mutation CreateEvent($input: CreateEventInput!) {
          createEvent(input: $input) {
            event {
              id
              name
              description
              place
              date
              category
              past
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
            input: {
              name: "Summer Music Festival",
              description: "Amazing outdoor concert",
              place: "Central Park, NYC",
              date: 1.month.from_now.iso8601,
              category: "music"
            }
          }
        end

        it "creates a new event" do
          expect {
            post "/graphql", params: { query: mutation, variables: variables }, headers: headers
          }.to change(Event, :count).by(1)

          event = Event.last
          expect(event.name).to eq("Summer Music Festival")
          expect(event.description).to eq("Amazing outdoor concert")
          expect(event.place).to eq("Central Park, NYC")
          expect(event.category).to eq("music")
        end

        it "returns the created event" do
          post "/graphql", params: { query: mutation, variables: variables }, headers: headers

          json = JSON.parse(response.body)
          data = json["data"]["createEvent"]

          expect(data["event"]).to be_present
          expect(data["event"]["name"]).to eq("Summer Music Festival")
          expect(data["event"]["category"]).to eq("music")
          expect(data["event"]["past"]).to be(false)
          expect(data["errors"]).to be_empty
        end

        it "returns the event ID" do
          post "/graphql", params: { query: mutation, variables: variables }, headers: headers

          json = JSON.parse(response.body)
          data = json["data"]["createEvent"]

          expect(data["event"]["id"]).to be_present
          expect(data["event"]["id"]).to eq(Event.last.id.to_s)
        end
      end

      context "with invalid date (in the past)" do
        let(:variables) do
          {
            input: {
              name: "Past Event",
              description: "This should fail",
              place: "Somewhere",
              date: 1.day.ago.iso8601,
              category: "music"
            }
          }
        end

        it "does not create an event" do
          expect {
            post "/graphql", params: { query: mutation, variables: variables }, headers: headers
          }.not_to change(Event, :count)
        end

        it "returns validation errors" do
          post "/graphql", params: { query: mutation, variables: variables }, headers: headers

          json = JSON.parse(response.body)
          data = json["data"]["createEvent"]

          expect(data["event"]).to be_nil
          expect(data["errors"]).to be_present
          expect(data["errors"].first).to include("must be in the future")
        end
      end

      context "with invalid category" do
        let(:variables) do
          {
            input: {
              name: "Event",
              description: "Test",
              place: "Somewhere",
              date: 1.month.from_now.iso8601,
              category: "invalid_category"
            }
          }
        end

        it "returns validation errors" do
          post "/graphql", params: { query: mutation, variables: variables }, headers: headers

          json = JSON.parse(response.body)
          data = json["data"]["createEvent"]

          expect(data["event"]).to be_nil
          expect(data["errors"]).to be_present
          expect(data["errors"].first).to include("must be one of")
        end
      end

      context "with missing required fields" do
        let(:variables) do
          {
            input: {
              name: "Event",
              description: "Test"
              # Missing place, date, category
            }
          }
        end

        it "returns GraphQL validation errors" do
          post "/graphql", params: { query: mutation, variables: variables }, headers: headers

          json = JSON.parse(response.body)

          expect(json["errors"]).to be_present
          error_message = json["errors"].first["message"]
          expect(error_message).to match(/place|date|category/)
        end
      end
    end

    context "when authenticated as regular user (non-admin)" do
      let(:headers) { { "Authorization" => "Bearer #{user_token}" } }
      let(:variables) do
        {
          input: {
            name: "Event",
            description: "Test",
            place: "Somewhere",
            date: 1.month.from_now.iso8601,
            category: "music"
          }
        }
      end

      it "returns an authorization error" do
        post "/graphql", params: { query: mutation, variables: variables }, headers: headers

        json = JSON.parse(response.body)

        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("Admin access required")
      end

      it "does not create an event" do
        expect {
          post "/graphql", params: { query: mutation, variables: variables }, headers: headers
        }.not_to change(Event, :count)
      end
    end

    context "when not authenticated" do
      let(:variables) do
        {
          input: {
            name: "Event",
            description: "Test",
            place: "Somewhere",
            date: 1.month.from_now.iso8601,
            category: "music"
          }
        }
      end

      it "returns an authentication error" do
        post "/graphql", params: { query: mutation, variables: variables }

        json = JSON.parse(response.body)

        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("You must be logged in to perform this action")
      end

      it "does not create an event" do
        expect {
          post "/graphql", params: { query: mutation, variables: variables }
        }.not_to change(Event, :count)
      end
    end
  end
end
