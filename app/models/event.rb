class Event < ApplicationRecord
  has_many :ticket_batches, dependent: :destroy
  has_many :tickets, dependent: :destroy
  has_one_attached :image

  scope :upcoming, -> { where("date > ?", DateTime.now).order(date: :asc) }
  scope :past, -> { where("date <= ?", DateTime.now).order(date: :desc) }

  enum :category, {
    music: "music",
    theater: "theater",
    sports: "sports",
    comedy: "comedy",
    conference: "conference",
    festival: "festival",
    exhibition: "exhibition",
    other: "other"
  }

  # Cache invalidation callbacks
  # Use after_commit to ensure cache is invalidated only after successful DB transaction
  after_commit :invalidate_events_cache, on: [ :create, :update, :destroy ]

  def past?
    date <= DateTime.now
  end

  private

  def invalidate_events_cache
    # Clear all events query caches when an event is created/updated/destroyed
    # This ensures users always see fresh data after any event changes
    begin
      # Clear events list cache (all variations with filters)
      Rails.cache.delete_matched("events_query:*")

      # Clear single event cache
      Rails.cache.delete("event:#{id}")

      Rails.logger.info("Invalidated events cache for event ID: #{id}")
    rescue => e
      # Log error but don't fail the transaction
      Rails.logger.error("Failed to invalidate cache: #{e.message}")
    end
  end
end
