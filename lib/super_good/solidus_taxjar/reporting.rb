module SuperGood
  module SolidusTaxjar
    class Reporting
      def initialize(api: SuperGood::SolidusTaxjar.api)
        @api = api
      end

      def create_refund(reimbursement)
        @api.create_refund_for(reimbursement)
      end

      def refund_all_transactions(order)
        # Find ALL non-refunded transactions for this order, regardless of address
        transactions_to_refund = SuperGood::SolidusTaxjar::OrderTransaction.latest_for(order)

        transactions_to_refund.each do |transaction|
          # Create refund for each existing transaction
          refund_response = @api.create_refund_transaction_for(transaction)
          transaction.create_refund_transaction!(
            transaction_id: refund_response.transaction_id,
            transaction_date: refund_response.transaction_date
          )
        end
      end

      def create_new_transaction(order, address, shipments)
        # Create new transaction for this specific address/shipment group
        if transaction_response = @api.create_transaction_for(order, address, shipments)
          order.taxjar_order_transactions.create!(
            transaction_id: transaction_response.transaction_id,
            transaction_date: transaction_response.transaction_date,
            address: address
          )
        end
      end

      def show_or_create_transaction(order, address, shipments)
        if transaction_response = @api.show_latest_transaction_for(order, address)
          SuperGood::SolidusTaxjar::OrderTransaction.find_by!(
            transaction_id: transaction_response.transaction_id
          )
        else
          transaction_response = @api.create_transaction_for(order, address, shipments)
          order.taxjar_order_transactions.create!(
            transaction_id: transaction_response.transaction_id,
            transaction_date: transaction_response.transaction_date,
            address: address
          )
        end
      end
    end
  end
end
