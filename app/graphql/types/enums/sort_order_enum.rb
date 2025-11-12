# frozen_string_literal: true

module Types
  module Enums
    class SortOrderEnum < Types::BaseEnum
      description "Sort order direction"

      value "ASC", "Ascending order", value: "asc"
      value "DESC", "Descending order", value: "desc"
    end
  end
end
