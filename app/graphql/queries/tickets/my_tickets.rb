# frozen_string_literal: true

module Queries
  module Tickets
    class MyTickets < Queries::BaseQuery
      description "Get all tickets for the current authenticated user"

      type [ Types::TicketType ], null: false

      def resolve
        require_authentication!

        ::Ticket
          .where(user_id: current_user.id)
          .includes(:event, :order, order: :ticket_batch)
          .order(created_at: :desc)
      end
    end
  end
end
