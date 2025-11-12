# frozen_string_literal: true

class ApplicationContract < Dry::Validation::Contract
  # Add shared validation rules and macros here
  config.messages.backend = :i18n
  config.messages.load_paths << "config/locales/en.yml"
end
