class CreateGuestUsers < ActiveRecord::Migration[8.0]
  def up
    create_table :guest_users do |t|
      t.string :device_fingerprint, null: false
      t.integer :remaining_uses, null: false, default: 20
      t.timestamps
    end

    add_index :guest_users, :device_fingerprint, unique: true

    add_reference :devices, :guest_user, foreign_key: { to_table: :guest_users }
  end

  def down
    remove_reference :devices, :guest_user, foreign_key: true
    drop_table :guest_users
  end
end
