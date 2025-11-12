# frozen_string_literal: true

module Queries
  module Tickets
    class GetTicket < Queries::BaseQuery
      description "Get ticket details by ID (admin can view any, user can view own)"

      type Types::TicketType, null: true

      argument :id, ID, required: true, description: "Ticket ID"

      def resolve(id:)
        require_authentication!

        ticket = ::Ticket.includes(:event, :order, order: :ticket_batch).find_by(id: id)
        return nil unless ticket

        # Admin can see any ticket, user can only see their own
        unless current_user.admin? || ticket.user_id == current_user.id
          raise GraphQL::ExecutionError, "Forbidden"
        end

        ticket
      end
    end
  end
end
