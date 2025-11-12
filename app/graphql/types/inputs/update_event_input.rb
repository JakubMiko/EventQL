# frozen_string_literal: true

module Types
  module Inputs
    class UpdateEventInput < Types::BaseInputObject
      description "Input for updating an existing event"

      argument :name, String, required: false, description: "Event name"
      argument :description, String, required: false, description: "Event description"
      argument :place, String, required: false, description: "Event location/venue"
      argument :date, GraphQL::Types::ISO8601DateTime, required: false, description: "Event date and time"
      argument :category, String, required: false, description: "Event category (music, theater, sports, comedy, conference, festival, exhibition, other)"
      argument :image_data, String, required: false, description: "Base64-encoded image data (e.g., 'data:image/png;base64,iVBORw0KGgo...')"
      argument :image_filename, String, required: false, description: "Original filename for the image (e.g., 'concert.jpg')"
    end
  end
end
