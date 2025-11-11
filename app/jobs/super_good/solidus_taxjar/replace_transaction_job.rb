# frozen_string_literal: true

module SuperGood
  module SolidusTaxjar
    class ReplaceTransactionJob < ApplicationJob
      queue_as { SuperGood::SolidusTaxjar.job_queue }

      def perform(order)
        return if order.total.zero?

        # Step 1: Refund ALL existing non-refunded transactions
        # This ensures orphaned transactions (from removed shipment groups) are also refunded
        begin
          SuperGood::SolidusTaxjar.reporting.refund_all_transactions(order)
        rescue Taxjar::Error => exception
          # Log the error but continue to try creating new transactions
          SuperGood::SolidusTaxjar::TransactionSyncLog.create!(
            order: order,
            status: :error,
            error_message: "Failed to refund transactions: #{exception.message}"
          )
        end

        # Step 2: Create new transactions for current shipment groups
        order.shipments.group_by(&:address).each do |address, shipments|
          begin
            # Create a new transaction for this specific address
            order_transaction = SuperGood::SolidusTaxjar.reporting.create_new_transaction(order, address, shipments)

            # Create sync log for this shipment group
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
