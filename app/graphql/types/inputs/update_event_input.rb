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
      argument :image, String, required: false, description: "Base64 encoded image data"
    end
  end
end
