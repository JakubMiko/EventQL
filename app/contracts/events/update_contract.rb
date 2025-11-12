# frozen_string_literal: true

module Events
  class UpdateContract < ApplicationContract
    params do
      optional(:name).filled(:string)
      optional(:description).filled(:string)
      optional(:place).filled(:string)
      optional(:category).filled(:string)
      optional(:date).filled
      optional(:image_data).filled(:string)
      optional(:image_filename).filled(:string)
    end

    rule(:date) do
      if value
        time_value = value.is_a?(String) ? Time.parse(value) : value
        key.failure("must be in the future") if time_value && time_value < Time.current
      end
    rescue ArgumentError
      key.failure("must be a valid date time")
    end

    rule(:category) do
      if value
        valid_categories = %w[music theater sports comedy conference festival exhibition other]
        key.failure("must be one of: #{valid_categories.join(', ')}") unless valid_categories.include?(value)
      end
    end
  end
end
