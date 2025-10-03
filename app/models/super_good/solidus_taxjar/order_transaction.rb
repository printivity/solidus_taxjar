module SuperGood
  module SolidusTaxjar
    class OrderTransaction < ActiveRecord::Base
      belongs_to :order, class_name: "Spree::Order"

      has_one :refund_transaction

      validates_presence_of :transaction_id
      validates_presence_of :transaction_date

      def self.latest_for(order)
        where(order: order).where.missing(:refund_transaction).order(transaction_date: :desc, created_at: :desc)
      end
    end
  end
end
