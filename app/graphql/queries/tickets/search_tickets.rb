# frozen_string_literal: true

module Queries
  module Tickets
    class SearchTickets < Queries::BaseQuery
      description "Search and filter tickets with advanced criteria (admin only)"

      type [ Types::TicketType ], null: false

      argument :filters, Types::Inputs::SearchTicketsInput, required: false, description: "Search filters"

      def resolve(filters: {})
        require_admin!

        # Handle exact ticket number lookup (returns single ticket or raises error)
        if filters[:ticket_number].present?
          ticket = ::Ticket.includes(:event, :order, order: :ticket_batch).find_by(ticket_number: filters[:ticket_number])
          raise GraphQL::ExecutionError, "Ticket not found" unless ticket
          return [ ticket ]
        end

        # Build query params for TicketsQuery
        query_params = {
          user_id: filters[:user_id],
          event_id: filters[:event_id],
          order_id: filters[:order_id],
          min_price: filters[:min_price],
          max_price: filters[:max_price],
          sort: filters[:sort] || "desc"
        }.compact

        ::TicketsQuery.new(params: query_params).call
      end
    end
  end
end
