# frozen_string_literal: true

module Resolvers
  class TicketBatchesResolver < BaseResolver
    type [ Types::TicketBatchType ], null: false

    argument :state, Types::Enums::TicketBatchStateEnum, required: false, default_value: "all", description: "Filter by state"
    argument :order, Types::Enums::SortOrderEnum, required: false, default_value: "desc", description: "Sort order by sale_start"

    def resolve(state:, order:)
      cache_key = "ticket_batches:event_#{object.id}:state_#{state}:order_#{order}"

      begin
        Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
          fetch_ticket_batches(state, order)
        end
      rescue => e
        Rails.logger.error("Redis cache fetch failed for ticket_batches event #{object.id}: #{e.message}")
        fetch_ticket_batches(state, order)
      end
    end

    private

    def fetch_ticket_batches(state, order)
      scope = object.ticket_batches
      scope = filter_by_state(scope, state)
      scope = sort_by_sale_start(scope, order)
      scope.to_a
    end

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

    def sort_by_sale_start(scope, order)
      order == "desc" ? scope.order(sale_start: :desc) : scope.order(sale_start: :asc)
    end
  end
end
