module SuperGood
  module SolidusTaxjar
    class OrderTransaction < ActiveRecord::Base
      belongs_to :order, class_name: "Spree::Order"
      belongs_to :address, class_name: "Spree::Address", optional: true

      has_one :refund_transaction

      validates_presence_of :transaction_id
      validates_presence_of :transaction_date

      def self.latest_for(order, address = nil)
        scope = where(order: order).where.missing(:refund_transaction).order(transaction_date: :desc, created_at: :desc)
        scope = scope.where(address: address) if address
        scope
      end
    end
  end
end
