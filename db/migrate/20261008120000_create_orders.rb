class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.string :external_id
      t.string :status, null: false, default: "NEW"
      t.string :email, null: false
      t.string :full_name, null: false
      t.string :phone_number, null: false
      t.string :address, null: false
      t.string :network
      t.string :payin_amount, null: false
      t.string :payin_currency
      t.string :payout_amount
      t.string :payout_currency
      t.string :rate
      t.string :invoice_url
      t.datetime :invoice_expires_at
      t.string :verification_url
      t.datetime :verification_expires_at
      t.string :error_code
      t.bigint :telegram_user_id
      t.jsonb :raw_payload, null: false, default: {}

      t.timestamps
    end

    add_index :orders, :external_id, unique: true, where: "external_id IS NOT NULL"
    add_index :orders, :status
  end
end
