# frozen_string_literal: true

module Types
  module Inputs
    class PayOrderInput < Types::BaseInputObject
      description "Input for paying an order"

      argument :id, ID, required: true, description: "ID of the order to pay"
      argument :amount, String, required: false, description: "Payment amount (as decimal string, e.g., '100.00'). Must match order total_price if provided."
      argument :payment_method, String, required: false, description: "Payment method (e.g., 'test', 'card_declined')"
      argument :force_payment_status, String, required: false, description: "Force payment outcome: 'success' or 'fail'"
    end
  end
end
