# frozen_string_literal: true

module Queries
  class BaseQuery < GraphQL::Schema::Resolver
    # Helper to get the current user from context
    def current_user
      context[:current_user]
    end

    # Require authentication - raises error if user not logged in
    def require_authentication!
      raise GraphQL::ExecutionError, "You must be logged in to perform this action" unless current_user
    end

    # Require admin access - raises error if user not admin
    def require_admin!
      require_authentication!
      raise GraphQL::ExecutionError, "Admin access required" unless current_user.admin?
    end
  end
end
