# frozen_string_literal: true

module Types
  module Inputs
    class UpdateTicketBatchInput < Types::BaseInputObject
      description "Input for updating an existing ticket batch"

      argument :available_tickets, Integer, required: false, description: "Number of tickets available in this batch"
      argument :price, String, required: false, description: "Price per ticket (as decimal string, e.g., '50.00')"
      argument :sale_start, GraphQL::Types::ISO8601DateTime, required: false, description: "When ticket sales begin"
      argument :sale_end, GraphQL::Types::ISO8601DateTime, required: false, description: "When ticket sales end"
    end
  end
end
