class CreateTicketBatches < ActiveRecord::Migration[8.0]
  def change
    create_table :ticket_batches do |t|
      t.references :event, null: false, foreign_key: true
      t.decimal :price
      t.integer :total_quantity
      t.integer :available_quantity

      t.timestamps
    end
  end
end
