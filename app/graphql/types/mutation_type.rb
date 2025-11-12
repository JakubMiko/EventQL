# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    # TODO: remove me
    field :test_field, String, null: false,
      description: "An example field added by the generator"
    def test_field
      "Hello World"
    end

    # User mutations
    field :register, mutation: Mutations::Users::Register
    field :login, mutation: Mutations::Users::Login
    field :change_password, mutation: Mutations::Users::ChangePassword
  end
end
