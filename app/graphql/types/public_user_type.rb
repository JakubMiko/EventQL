# frozen_string_literal: true

module Types
  class PublicUserType < Types::BaseObject
    description "Public user profile information (limited fields for privacy)"

    field :id, ID, null: false
    field :email, String, null: false
    field :first_name, String, null: true
    field :last_name, String, null: true
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
