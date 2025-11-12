# frozen_string_literal: true

module Types
  class QueryType < Types::BaseObject
    field :node, Types::NodeType, null: true, description: "Fetches an object given its ID." do
      argument :id, ID, required: true, description: "ID of the object."
    end

    def node(id:)
      context.schema.object_from_id(id, context)
    end

    field :nodes, [ Types::NodeType, null: true ], null: true, description: "Fetches a list of objects given a list of IDs." do
      argument :ids, [ ID ], required: true, description: "IDs of the objects."
    end

    def nodes(ids:)
      ids.map { |id| context.schema.object_from_id(id, context) }
    end

    # Add root-level fields here.
    # They will be entry points for queries on your schema.

    # TODO: remove me
    field :test_field, String, null: false,
      description: "An example field added by the generator"
    def test_field
      "Hello World!"
    end

    # Event queries
    field :events, resolver: Queries::Events::Index, description: "Get all events with optional filters (no auth required)"
    field :event, resolver: Queries::Events::Event, description: "Get full event data by ID (no auth required)"

    # Ticket batch queries
    field :ticket_batch, resolver: Queries::TicketBatches::Show, description: "Get ticket batch by ID (no auth required)"

    # User queries
    field :public_user, resolver: Queries::Users::PublicUser, description: "Get public user profile (no auth required)"
    field :current_user, resolver: Queries::Users::CurrentUser, description: "Get current logged-in user (requires auth)"
    field :user, resolver: Queries::Users::Show, description: "Get full user data by ID (admin only)"
  end
end
