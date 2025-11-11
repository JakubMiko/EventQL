class UpdateTicketBatchesUpdateColumns < ActiveRecord::Migration[8.0]
  def change
    rename_column :ticket_batches, :total_quantity, :available_tickets
    remove_column :ticket_batches, :available_quantity, :integer
    add_column :ticket_batches, :sale_start, :datetime
    add_column :ticket_batches, :sale_end, :datetime
  end
end
