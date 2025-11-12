# frozen_string_literal: true

module Events
  class CreateContract < ApplicationContract
    params do
      required(:name).filled(:string)
      required(:description).filled(:string)
      required(:place).filled(:string)
      required(:category).filled(:string)
      required(:date).filled
      optional(:image)
    end

    rule(:date) do
      # Convert to Time if it's a string
      time_value = value.is_a?(String) ? Time.parse(value) : value
      key.failure("must be in the future") if time_value && time_value < Time.current
    rescue ArgumentError
      key.failure("must be a valid date time")
    end

    rule(:category) do
      valid_categories = %w[music theater sports comedy conference festival exhibition other]
      key.failure("must be one of: #{valid_categories.join(', ')}") unless valid_categories.include?(value)
    end
  end
end
