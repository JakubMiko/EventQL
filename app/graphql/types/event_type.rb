module Types
  class EventType < Types::BaseObject
    description "An event that users can purchase tickets for"

    field :id, ID, null: false, description: "Unique identifier"
    field :name, String, null: false, description: "Event name"
    field :description, String, null: true, description: "Event description"
    field :date, GraphQL::Types::ISO8601DateTime, null: false, description: "Event date and time"
    field :category, String, null: false, description: "Event category (music, theater, sports, etc.)"
    field :place, String, null: false, description: "Event location/venue"
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When the event was created"
    field :updated_at, GraphQL::Types::ISO8601DateTime, null: false, description: "When the event was last updated"

    # Computed fields
    field :past, Boolean, null: false, description: "Whether the event has already occurred"
    field :image_url, String, null: true, description: "URL of the event image"

    # Associations
    field :ticket_batches, resolver: Resolvers::TicketBatchesResolver, description: "Ticket batches for this event"
    field :tickets, [ Types::TicketType ], null: false, description: "All tickets sold for this event"

    def past
      object.past?
    end

    def image_url
      return nil unless object.image.attached?

      Rails.application.routes.url_helpers.rails_blob_url(object.image, only_path: true)
    end
  end
end
