class AddRemainingUsesToUser < ActiveRecord::Migration[8.0]
  def up
    add_column :users_tables, :remaining_uses, :integer, default: 10
  end

  def down
    remove_column :users_tables, :remaining_uses
  end
end
