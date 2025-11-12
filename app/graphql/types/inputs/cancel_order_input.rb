# frozen_string_literal: true

module Types
  module Inputs
    class CancelOrderInput < Types::BaseInputObject
      description "Input for cancelling an order"

      argument :id, ID, required: true, description: "ID of the order to cancel"
    end
  end
end
