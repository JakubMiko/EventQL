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

    # Event mutations (admin only)
    field :create_event, mutation: Mutations::Events::Create
    field :update_event, mutation: Mutations::Events::Update
    field :delete_event, mutation: Mutations::Events::Delete

    # Ticket batch mutations (admin only)
    field :create_ticket_batch, mutation: Mutations::TicketBatches::Create
    field :update_ticket_batch, mutation: Mutations::TicketBatches::Update
    field :delete_ticket_batch, mutation: Mutations::TicketBatches::Delete
  end
end
