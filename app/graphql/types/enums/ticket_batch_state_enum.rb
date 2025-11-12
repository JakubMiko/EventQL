# frozen_string_literal: true

module Types
  module Enums
    class TicketBatchStateEnum < Types::BaseEnum
      description "State of a ticket batch"

      value "AVAILABLE", "Tickets are currently on sale and available", value: "available"
      value "SOLD_OUT", "All tickets have been sold", value: "sold_out"
      value "EXPIRED", "Sales period has ended", value: "expired"
      value "INACTIVE", "Sales have not yet started", value: "inactive"
      value "ALL", "All ticket batches regardless of state", value: "all"
    end
  end
end
