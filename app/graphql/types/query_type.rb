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

    # Event queries
    field :events, resolver: Queries::Events::ListEvents, description: "Get all events with optional filters (no auth required)", max_page_size: 50, default_page_size: 10
    field :event, resolver: Queries::Events::GetEvent, description: "Get full event data by ID (no auth required)"

    # Ticket batch queries
    field :ticket_batch, resolver: Queries::TicketBatches::GetTicketBatch, description: "Get ticket batch by ID (no auth required)"

    # User queries
    field :public_user, resolver: Queries::Users::PublicUser, description: "Get public user profile (no auth required)"
    field :current_user, resolver: Queries::Users::CurrentUser, description: "Get current logged-in user (requires auth)"
    field :user, resolver: Queries::Users::GetUser, description: "Get full user data by ID (admin only)"

    # Order queries
    field :my_orders, resolver: Queries::Orders::MyOrders, description: "Get current user's orders (requires auth)"
    field :order, resolver: Queries::Orders::GetOrder, description: "Get order by ID (admin any, user own)"
    field :all_orders, resolver: Queries::Orders::AllOrders, description: "Get all orders with optional filter (admin only)"

    # Ticket queries
    field :my_tickets, resolver: Queries::Tickets::MyTickets, description: "Get current user's tickets (requires auth)"
    field :ticket, resolver: Queries::Tickets::GetTicket, description: "Get ticket by ID (admin any, user own)"
    field :search_tickets, resolver: Queries::Tickets::SearchTickets, description: "Search tickets with filters (admin only)"
  end
end
