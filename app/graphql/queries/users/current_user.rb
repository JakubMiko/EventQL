# frozen_string_literal: true

module Queries
  module Users
    class CurrentUser < Queries::BaseQuery
      description "Get the currently logged-in user"

      type Types::UserType, null: true

      def resolve
        require_authentication!
        current_user
      end
    end
  end
end
