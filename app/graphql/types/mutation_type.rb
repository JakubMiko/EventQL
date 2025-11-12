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
    field :create_event, mutation: Mutations::Events::CreateEvent
    field :update_event, mutation: Mutations::Events::UpdateEvent
    field :delete_event, mutation: Mutations::Events::DeleteEvent

    # Ticket batch mutations (admin only)
    field :create_ticket_batch, mutation: Mutations::TicketBatches::CreateTicketBatch
    field :update_ticket_batch, mutation: Mutations::TicketBatches::UpdateTicketBatch
    field :delete_ticket_batch, mutation: Mutations::TicketBatches::DeleteTicketBatch

    # Order mutations
    field :create_order, mutation: Mutations::Orders::CreateOrder
    field :cancel_order, mutation: Mutations::Orders::CancelOrder
    field :pay_order, mutation: Mutations::Orders::PayOrder
  end
end
