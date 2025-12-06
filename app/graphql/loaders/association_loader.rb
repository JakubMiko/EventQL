# frozen_string_literal: true

module Loaders
  # Generic association loader for batch-loading has_many associations
  # Usage: dataloader.with(Loaders::AssociationLoader, Event, :ticket_batches).load(event.id)
  class AssociationLoader < GraphQL::Dataloader::Source
    def initialize(model_class, association_name)
      super()
      @model_class = model_class
      @association_name = association_name
    end

    def fetch(ids)
      # Preload the association for all records at once
      records = @model_class.where(id: ids).includes(@association_name)

      # Build a hash mapping: record_id => associated_records
      records_hash = records.each_with_object({}) do |record, hash|
        hash[record.id] = record.public_send(@association_name).to_a
      end

      # Return results in the same order as the input ids
      ids.map { |id| records_hash[id] || [] }
    end
  end
end
