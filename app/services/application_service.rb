# frozen_string_literal: true

class ApplicationService
  include Dry::Monads[:result]

  # Class method to call the service
  # Usage: MyService.call(args)
  def self.call(...)
    new(...).call
  end
end
