# frozen_string_literal: true

module Mutations
  module Users
    class Login < Mutations::BaseMutation
      graphql_name "LoginPayload"
      description "Login with email and password"

      # Arguments - using Input Object Type
      argument :input, Types::Inputs::LoginInput, required: true

      # Return fields
      field :token, String, null: true, description: "JWT authentication token"
      field :user, Types::UserType, null: true, description: "The authenticated user"
      field :errors, [ String ], null: false, description: "Error messages if login fails"

      def resolve(input:)
        user = User.find_by(email: input.email)

        unless user&.valid_password?(input.password)
          return {
            token: nil,
            user: nil,
            errors: [ "Invalid email or password" ]
          }
        end

        # Generate JWT token
        token = Authentication.encode_token({ user_id: user.id })

        {
          token: token,
          user: user,
          errors: []
        }
      end
    end
  end
end
