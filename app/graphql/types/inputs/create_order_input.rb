# frozen_string_literal: true

module Types
  module Inputs
    class CreateOrderInput < Types::BaseInputObject
      description "Input for creating a new order"

      argument :ticket_batch_id, ID, required: true, description: "ID of the ticket batch to purchase from"
      argument :quantity, Integer, required: true, description: "Number of tickets to purchase (must be greater than 0)"
    end
  end
end
