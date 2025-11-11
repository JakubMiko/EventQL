# frozen_string_literal: true

module Queries
  class BaseQuery < GraphQL::Schema::Resolver
    # Add any shared query logic here
    # For example, you could add authorization helpers

    # def authorized_user
    #   context[:current_user] || raise_unauthorized
    # end

    # def raise_unauthorized
    #   raise GraphQL::ExecutionError, "You must be logged in to perform this action"
    # end
  end
end
