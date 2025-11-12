# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mutations::Events::Delete, type: :request do
  describe ".resolve" do
    let!(:admin) { create(:user, admin: true, email: "admin@example.com", password: "password123") }
    let!(:regular_user) { create(:user, admin: false, email: "user@example.com", password: "password123") }
    let!(:event) { create(:event, name: "Event to Delete") }
    let(:admin_token) { Authentication.encode_token({ user_id: admin.id }) }
    let(:user_token) { Authentication.encode_token({ user_id: regular_user.id }) }

    let(:mutation) do
      <<~GRAPHQL
        mutation DeleteEvent($id: ID!) {
          deleteEvent(id: $id) {
            success
            message
          }
        }
      GRAPHQL
    end

    context "when authenticated as admin" do
      let(:headers) { { "Authorization" => "Bearer #{admin_token}" } }

      context "when event exists" do
        let(:variables) { { id: event.id } }

        it "deletes the event" do
          expect {
            post "/graphql", params: { query: mutation, variables: variables }, headers: headers
          }.to change(Event, :count).by(-1)

          expect(Event.find_by(id: event.id)).to be_nil
        end

        it "returns success response" do
          post "/graphql", params: { query: mutation, variables: variables }, headers: headers

          json = JSON.parse(response.body)
          data = json["data"]["deleteEvent"]

          expect(data["success"]).to be(true)
          expect(data["message"]).to eq("Event deleted successfully")
        end
      end

      context "when event does not exist" do
        let(:variables) { { id: 99999 } }

        it "does not change event count" do
          expect {
            post "/graphql", params: { query: mutation, variables: variables }, headers: headers
          }.not_to change(Event, :count)
        end

        it "returns an error" do
          post "/graphql", params: { query: mutation, variables: variables }, headers: headers

          json = JSON.parse(response.body)
          data = json["data"]["deleteEvent"]

          expect(data["success"]).to be(false)
          expect(data["message"]).to eq("Event not found")
        end
      end

      context "when event has associated ticket batches" do
        let!(:ticket_batch) { create(:ticket_batch, event: event) }
        let(:variables) { { id: event.id } }

        it "deletes the event and cascades to ticket batches" do
          expect {
            post "/graphql", params: { query: mutation, variables: variables }, headers: headers
          }.to change(Event, :count).by(-1)
            .and change(TicketBatch, :count).by(-1)
        end

        it "returns success" do
          post "/graphql", params: { query: mutation, variables: variables }, headers: headers

          json = JSON.parse(response.body)
          data = json["data"]["deleteEvent"]

          expect(data["success"]).to be(true)
        end
      end
    end

    context "when authenticated as regular user (non-admin)" do
      let(:headers) { { "Authorization" => "Bearer #{user_token}" } }
      let(:variables) { { id: event.id } }

      it "returns an authorization error" do
        post "/graphql", params: { query: mutation, variables: variables }, headers: headers

        json = JSON.parse(response.body)

        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("Admin access required")
      end

      it "does not delete the event" do
        expect {
          post "/graphql", params: { query: mutation, variables: variables }, headers: headers
        }.not_to change(Event, :count)

        expect(Event.find_by(id: event.id)).to be_present
      end
    end

    context "when not authenticated" do
      let(:variables) { { id: event.id } }

      it "returns an authentication error" do
        post "/graphql", params: { query: mutation, variables: variables }

        json = JSON.parse(response.body)

        expect(json["errors"]).to be_present
        expect(json["errors"].first["message"]).to eq("You must be logged in to perform this action")
      end

      it "does not delete the event" do
        expect {
          post "/graphql", params: { query: mutation, variables: variables }
        }.not_to change(Event, :count)

        expect(Event.find_by(id: event.id)).to be_present
      end
    end
  end
end
