# frozen_string_literal: true

module Queries
  module Users
    class PublicUser < Queries::BaseQuery
      description "Get public user profile by ID"

      type Types::PublicUserType, null: true
      argument :id, ID, required: true, description: "User ID"

      def resolve(id:)
        user = User.find_by(id: id)
        raise GraphQL::ExecutionError, "User not found" unless user

        user
      end
    end
  end
end
