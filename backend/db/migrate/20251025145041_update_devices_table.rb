class UpdateDevicesTable < ActiveRecord::Migration[8.0]
  def up
    add_column :devices, :device_fingerprint, :string
    add_index :devices, :device_fingerprint

    remove_column :devices, :stripe_customer_id, :string
    remove_column :devices, :paid, :boolean
    remove_column :devices, :remaining_uses, :integer
  end

  def down
    remove_index :devices, :device_fingerprint
    remove_column :devices, :device_fingerprint

    add_column :devices, :stripe_customer_id, :string
    add_column :devices, :paid, :boolean, default: false, null: false
    add_column :devices, :remaining_uses, :integer, default: 5, null: false
  end
end
