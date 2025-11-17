# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Events::CreateEvent, type: :request do
  describe ".resolve" do
    let!(:admin) { create(:user, admin: true, email: "admin@example.com", password: "password123") }
    let!(:regular_user) { create(:user, admin: false, email: "user@example.com", password: "password123") }
    let(:admin_token) { Authentication.encode_token({ user_id: admin.id }) }
    let(:user_token) { Authentication.encode_token({ user_id: regular_user.id }) }

    # A tiny 1x1 pixel PNG image in base64
    let(:valid_base64_image) do
      "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
    end

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

    context "with image upload" do
      let(:headers) { { "Authorization" => "Bearer #{admin_token}" } }

      let(:mutation_with_image) do
        <<~GRAPHQL
          mutation CreateEvent($input: CreateEventInput!) {
            createEvent(input: $input) {
              event {
                id
                name
                description
                place
                category
              }
              errors
            }
          }
        GRAPHQL
      end

      context "with valid base64 image" do
        let(:variables) do
          {
            input: {
              name: "Photo Event",
              description: "Event with image",
              place: "Gallery",
              date: 1.month.from_now.iso8601,
              category: "exhibition",
              imageData: valid_base64_image,
              imageFilename: "poster.png"
            }
          }
        end

        it "creates event with attached image" do
          post "/graphql", params: { query: mutation_with_image, variables: variables }, headers: headers

          json = JSON.parse(response.body)
          data = json["data"]["createEvent"]

          expect(data["event"]).to be_present
          expect(data["errors"]).to be_empty

          event = Event.last
          expect(event.image).to be_attached
          expect(event.image.filename.to_s).to eq("poster.png")
          expect(event.image.content_type).to eq("image/png")
        end
      end

      context "with image but no filename" do
        let(:variables) do
          {
            input: {
              name: "Event",
              description: "Test",
              place: "Place",
              date: 1.month.from_now.iso8601,
              category: "music",
              imageData: valid_base64_image
            }
          }
        end

        it "generates filename from content type" do
          post "/graphql", params: { query: mutation_with_image, variables: variables }, headers: headers

          event = Event.last
          expect(event.image).to be_attached
          expect(event.image.filename.to_s).to eq("upload.png")
        end
      end

      context "with invalid base64 data" do
        let(:variables) do
          {
            input: {
              name: "Event",
              description: "Test",
              place: "Place",
              date: 1.month.from_now.iso8601,
              category: "music",
              imageData: "not-a-valid-base64-image"
            }
          }
        end

        it "returns error and does not create event" do
          expect {
            post "/graphql", params: { query: mutation_with_image, variables: variables }, headers: headers
          }.not_to change(Event, :count)

          json = JSON.parse(response.body)
          data = json["data"]["createEvent"]

          expect(data["event"]).to be_nil
          expect(data["errors"]).to be_present
          expect(data["errors"].first).to include("Invalid image format")
        end
      end

      context "without image data" do
        let(:variables) do
          {
            input: {
              name: "Event",
              description: "Test",
              place: "Place",
              date: 1.month.from_now.iso8601,
              category: "music"
            }
          }
        end

        it "creates event without image" do
          post "/graphql", params: { query: mutation_with_image, variables: variables }, headers: headers

          json = JSON.parse(response.body)
          data = json["data"]["createEvent"]

          expect(data["event"]).to be_present
          expect(data["errors"]).to be_empty

          event = Event.last
          expect(event.image).not_to be_attached
        end
      end
    end
  end
end
