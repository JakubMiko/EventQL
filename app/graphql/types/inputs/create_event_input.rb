# frozen_string_literal: true

module Types
  module Inputs
    class CreateEventInput < Types::BaseInputObject
      description "Input for creating a new event"

      argument :name, String, required: true, description: "Event name"
      argument :description, String, required: true, description: "Event description"
      argument :place, String, required: true, description: "Event location/venue"
      argument :date, GraphQL::Types::ISO8601DateTime, required: true, description: "Event date and time"
      argument :category, String, required: true, description: "Event category (music, theater, sports, comedy, conference, festival, exhibition, other)"
      argument :image, String, required: false, description: "Base64 encoded image data"
    end
  end
end
