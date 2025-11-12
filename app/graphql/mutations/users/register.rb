# frozen_string_literal: true

module Mutations
  module Users
    class Register < Mutations::BaseMutation
      description "Register a new user account"

      # Arguments - using Input Object Type
      argument :input, Types::Inputs::RegisterInput, required: true

      # Return fields
      field :token, String, null: true, description: "JWT authentication token"
      field :user, Types::UserType, null: true, description: "The newly created user"
      field :errors, [ String ], null: false, description: "Error messages if registration fails"

      def resolve(input:)
        user = User.new(
          first_name: input.first_name,
          last_name: input.last_name,
          email: input.email,
          password: input.password,
          password_confirmation: input.password_confirmation
        )

        if user.save
          # Generate JWT token
          token = Authentication.encode_token({ user_id: user.id })

          {
            token: token,
            user: user,
            errors: []
          }
        else
          {
            token: nil,
            user: nil,
            errors: user.errors.full_messages
          }
        end
      end
    end
  end
end
