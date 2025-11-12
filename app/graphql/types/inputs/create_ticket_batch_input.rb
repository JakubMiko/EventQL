# frozen_string_literal: true

module Types
  module Inputs
    class CreateTicketBatchInput < Types::BaseInputObject
      description "Input for creating a new ticket batch"

      argument :event_id, ID, required: true, description: "ID of the event this batch belongs to"
      argument :available_tickets, Integer, required: true, description: "Number of tickets available in this batch"
      argument :price, String, required: true, description: "Price per ticket (as decimal string, e.g., '50.00')"
      argument :sale_start, GraphQL::Types::ISO8601DateTime, required: true, description: "When ticket sales begin"
      argument :sale_end, GraphQL::Types::ISO8601DateTime, required: true, description: "When ticket sales end"
    end
  end
end
