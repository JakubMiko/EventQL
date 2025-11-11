class UpdateEventsRenameColumns < ActiveRecord::Migration[8.0]
  def change
    rename_column :events, :title, :name
    rename_column :events, :location, :place
  end
end
