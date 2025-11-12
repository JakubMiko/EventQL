# frozen_string_literal: true

module Events
  class CreateService < ApplicationService
    attr_reader :params

    def initialize(params)
      @params = params.to_h.deep_stringify_keys
    end

    def call
      # Validate input with contract
      result = Events::CreateContract.new.call(params)
      return Failure(format_errors(result.errors)) unless result.success?

      validated_params = result.to_h

      # Extract image fields (these are NOT database columns, just GraphQL input)
      # We must remove them before creating the Event, otherwise ActiveRecord
      # will error with "unknown attribute 'image_data' for Event"
      # Note: Try both string and symbol keys since the source might vary
      image_data = validated_params.delete("image_data") || validated_params.delete(:image_data)
      image_filename = validated_params.delete("image_filename") || validated_params.delete(:image_filename)

      # Create event with only database columns
      event = Event.new(validated_params)

      if image_data.present?
        attachment_result = ImageAttachmentService.call(
          record: event,
          attachment_name: :image,
          image_data: image_data,
          filename: image_filename
        )
        return attachment_result if attachment_result.failure?
      end

      if event.save
        Success(event)
      else
        Failure(event.errors.full_messages.join(", "))
      end
    end

    private

    def format_errors(errors)
      errors.to_h.map { |key, messages| "#{key.to_s.humanize} #{messages.join(', ')}" }.join("; ")
    end
  end
end
