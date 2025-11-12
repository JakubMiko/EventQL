# frozen_string_literal: true

module Types
  module Inputs
    class ChangePasswordInput < Types::BaseInputObject
      description "Input for changing user password"

      argument :current_password, String, required: true, description: "Current password for verification"
      argument :new_password, String, required: true, description: "New password to set"
      argument :new_password_confirmation, String, required: true, description: "Confirmation of new password"
    end
  end
end
