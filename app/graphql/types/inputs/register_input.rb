# frozen_string_literal: true

module Types
  module Inputs
    class RegisterInput < Types::BaseInputObject
      description "Input for user registration"

      argument :first_name, String, required: true, description: "User's first name"
      argument :last_name, String, required: true, description: "User's last name"
      argument :email, String, required: true, description: "User's email address"
      argument :password, String, required: true, description: "User's password"
      argument :password_confirmation, String, required: true, description: "Password confirmation"
    end
  end
end
