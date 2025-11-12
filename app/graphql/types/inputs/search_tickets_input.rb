# frozen_string_literal: true

module Types
  module Inputs
    class SearchTicketsInput < Types::BaseInputObject
      description "Input for searching/filtering tickets (admin only)"

      argument :ticket_number, String, required: false, description: "Exact ticket number lookup (returns single ticket)"
      argument :user_id, ID, required: false, description: "Filter by user ID"
      argument :event_id, ID, required: false, description: "Filter by event ID"
      argument :order_id, ID, required: false, description: "Filter by order ID"
      argument :min_price, String, required: false, description: "Minimum price (as decimal string, e.g., '10.00')"
      argument :max_price, String, required: false, description: "Maximum price (as decimal string, e.g., '100.00')"
      argument :sort, Types::Enums::SortOrderEnum, required: false, description: "Sort order: 'asc' or 'desc' (default: 'desc')"
    end
  end
end
