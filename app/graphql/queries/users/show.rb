# frozen_string_literal: true

module Queries
  module Users
    class Show < Queries::BaseQuery
      description "Get full user data by ID (admin only)"

      type Types::UserType, null: true
      argument :id, ID, required: true, description: "User ID"

      def resolve(id:)
        require_admin!

        user = User.find_by(id: id)
        raise GraphQL::ExecutionError, "User not found" unless user

        user
      end
    end
  end
end
