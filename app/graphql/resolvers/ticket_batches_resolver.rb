# frozen_string_literal: true

module Resolvers
  class TicketBatchesResolver < BaseResolver
    type [ Types::TicketBatchType ], null: false

    argument :state, Types::Enums::TicketBatchStateEnum, required: false, default_value: "available", description: "Filter by state"
    argument :order, Types::Enums::SortOrderEnum, required: false, default_value: "asc", description: "Sort order by price"

    def resolve(state:, order:)
      scope = object.ticket_batches

      scope = filter_by_state(scope, state)
      scope = sort_by_price(scope, order)

      scope
    end

    private

    def filter_by_state(scope, state)
      return scope if state == "all"

      now = Time.current

      case state
      when "available"
        scope.where("sale_start <= ? AND sale_end >= ? AND available_tickets > 0", now, now)
      when "inactive"
        scope.where("sale_start > ?", now)
      when "expired"
        scope.where("sale_end < ?", now)
      when "sold_out"
        scope.where("sale_start <= ? AND sale_end >= ? AND available_tickets = 0", now, now)
      else
        scope
      end
    end

    def sort_by_price(scope, order)
      order == "desc" ? scope.order(price: :desc) : scope.order(price: :asc)
    end
  end
end
