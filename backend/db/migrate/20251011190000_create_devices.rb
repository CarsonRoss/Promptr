class CreateDevices < ActiveRecord::Migration[8.0]
  def change
    create_table :devices do |t|
      t.string  :device_id, null: false
      t.integer :remaining_uses, null: false, default: 5
      t.boolean :paid, null: false, default: false
      t.string  :stripe_customer_id
      t.datetime :last_seen_at

      t.timestamps
    end
    add_index :devices, :device_id, unique: true
    add_index :devices, :paid
    add_index :devices, :last_seen_at
  end
end


