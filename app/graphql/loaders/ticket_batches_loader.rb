# frozen_string_literal: true

module Loaders
  class TicketBatchesLoader < GraphQL::Dataloader::Source
    def initialize(state: "all", order: "desc")
      super()
      @state = state
      @order = order
    end

    def fetch(event_ids)
      scope = TicketBatch.where(event_id: event_ids)
      scope = filter_by_state(scope, @state)
      scope = sort_by_sale_start(scope, @order)

      batches_by_event = scope.group_by(&:event_id)
      event_ids.map { |event_id| batches_by_event[event_id] || [] }
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

    def sort_by_sale_start(scope, order)
      order == "desc" ? scope.order(sale_start: :desc) : scope.order(sale_start: :asc)
    end
  end
end
