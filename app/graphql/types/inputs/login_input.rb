# frozen_string_literal: true

module Types
  module Inputs
    class LoginInput < Types::BaseInputObject
      description "Input for user login"

      argument :email, String, required: true, description: "User's email address"
      argument :password, String, required: true, description: "User's password"
    end
  end
end
