class TicketBatch < ApplicationRecord
  belongs_to :event
  has_many :orders, dependent: :destroy

  after_commit :invalidate_cache

  private

  def invalidate_cache
    Rails.cache.delete_matched("ticket_batches:event_#{event_id}:*")
  end
end
