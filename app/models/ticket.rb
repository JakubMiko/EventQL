class Ticket < ApplicationRecord
  belongs_to :order
  belongs_to :user
  belongs_to :event
end
