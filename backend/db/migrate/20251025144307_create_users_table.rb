class CreateUsersTable < ActiveRecord::Migration[8.0]
  def up
    create_table :users_tables do |t|
      t.timestamps
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :status, null: false, default: 'unpaid'
      t.datetime :verified_at
      t.datetime :last_login_at
      t.index :email, unique: true
    end
  end

  def down
    drop_table :users_tables
  end
end
