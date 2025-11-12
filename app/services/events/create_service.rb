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

      # Create event
      event = Event.new(result.to_h)

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
