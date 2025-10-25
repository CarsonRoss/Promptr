class UpdateUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :devices, :stripe_customer_id, :string
  end

  def down
    remove_column :devices, :stripe_customer_id, :string
  end
end
