class AddAddressToOrderTransactions < ActiveRecord::Migration[5.0]
  def change
    add_reference :solidus_taxjar_order_transactions, :address, foreign_key: { to_table: :spree_addresses }
    add_index :solidus_taxjar_order_transactions, [:order_id, :address_id], name: 'index_order_transactions_on_order_and_address'
  end
end
