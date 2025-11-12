# frozen_string_literal: true

module Mutations
  module Users
    class ChangePassword < Mutations::BaseMutation
      description "Change password for the currently logged-in user"

      # Arguments - using Input Object Type
      argument :input, Types::Inputs::ChangePasswordInput, required: true

      # Return fields
      field :success, Boolean, null: false, description: "Whether the password change was successful"
      field :message, String, null: true, description: "Success message"
      field :errors, [ String ], null: false, description: "Error messages if password change fails"

      def resolve(input:)
        require_authentication!

        user = current_user

        # Validate current password
        unless user.valid_password?(input.current_password)
          return {
            success: false,
            message: nil,
            errors: [ "Current password is incorrect" ]
          }
        end

        # Validate password confirmation
        if input.new_password != input.new_password_confirmation
          return {
            success: false,
            message: nil,
            errors: [ "Password confirmation does not match" ]
          }
        end

        # Update password
        if user.update(password: input.new_password, password_confirmation: input.new_password_confirmation)
          {
            success: true,
            message: "Password changed successfully",
            errors: []
          }
        else
          {
            success: false,
            message: nil,
            errors: user.errors.full_messages
          }
        end
      end
    end
  end
end
