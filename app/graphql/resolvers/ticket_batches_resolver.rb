# frozen_string_literal: true

module Resolvers
  class TicketBatchesResolver < BaseResolver
    type [ Types::TicketBatchType ], null: false

    argument :state, Types::Enums::TicketBatchStateEnum, required: false, default_value: "all", description: "Filter by state"
    argument :order, Types::Enums::SortOrderEnum, required: false, default_value: "desc", description: "Sort order by sale_start"

    def resolve(state:, order:)
      dataloader.with(Loaders::TicketBatchesLoader, state: state, order: order).load(object.id)
    end
  end
end
