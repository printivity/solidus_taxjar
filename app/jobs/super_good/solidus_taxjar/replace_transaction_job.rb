# frozen_string_literal: true

module SuperGood
  module SolidusTaxjar
    class ReplaceTransactionJob < ApplicationJob
      queue_as { SuperGood::SolidusTaxjar.job_queue }

      def perform(order)
        order.shipments.group_by(&:address).each do |address, shipments|
          begin
            latest_order_transactions = OrderTransaction.latest_for(order)

            latest_order_transactions.each do |transaction|
              transaction_response = @api.create_refund_transaction_for(order)
              transaction.create_refund_transaction!(
                transaction_id: transaction_response.transaction_id,
                transaction_date: transaction_response.transaction_date
              )
            end

            return if order.total.zero?

            order_transaction = SuperGood::SolidusTaxjar.reporting.refund_and_create_new_transaction(order, address, shipments)

            SuperGood::SolidusTaxjar::TransactionSyncLog.create!(
              order: order,
              order_transaction: order_transaction,
              status: :success
            )
          rescue Taxjar::Error => exception
            SuperGood::SolidusTaxjar::TransactionSyncLog.create!(
              order: order,
              status: :error,
              error_message: exception.message
            )
          end
        end
      end
    end
  end
end
