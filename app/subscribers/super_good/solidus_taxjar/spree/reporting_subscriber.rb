module SuperGood
  module SolidusTaxjar
    module Spree
      class ReportingSubscriber
        include Omnes::Subscriber

        ORDER_TOO_OLD_MESSAGE = "Order cannot be synced because it was completed before TaxJar reporting was enabled"

        handle :shipment_shipped, with: :report_transaction
        handle :order_recalculated, with: :replace_transaction
        handle :reimbursement_reimbursed, with: :create_refund

        def report_transaction(event)
          shipment = event.payload[:shipment]
          order = shipment.order

          return unless SuperGood::SolidusTaxjar.configuration.preferred_reporting_enabled

          if completed_before_reporting_enabled?(order)
            order.taxjar_transaction_sync_logs.create!(status: :error, error_message: ORDER_TOO_OLD_MESSAGE)
            SuperGood::SolidusTaxjar.exception_handler.call(RuntimeError.new(ORDER_TOO_OLD_MESSAGE))
            return
          end

          if reportable_order?(order)
            SuperGood::SolidusTaxjar::ReportTransactionJob.perform_later(order)
          end
        end

        def replace_transaction(event)
          return unless SuperGood::SolidusTaxjar.configuration.preferred_reporting_enabled

          order = event.payload[:order]

          return unless order.completed? && order.shipped?

          if completed_before_reporting_enabled?(order)
            order.taxjar_transaction_sync_logs.create!(status: :error, error_message: ORDER_TOO_OLD_MESSAGE)
            SuperGood::SolidusTaxjar.exception_handler.call(RuntimeError.new(ORDER_TOO_OLD_MESSAGE))
            return
          end

          if reportable_order?(order) && transaction_replaceable?(order) && amount_changed?(order)
            SuperGood::SolidusTaxjar::ReplaceTransactionJob.perform_later(order)
          end
        end

        def create_refund(event)
          reimbursement = event.payload[:reimbursement]
          order = reimbursement.order

          return unless SuperGood::SolidusTaxjar.configuration.preferred_reporting_enabled

          if reportable_order?(order) && transaction_refundable?(order)
            SuperGood::SolidusTaxjar::ReportRefundJob.perform_later(reimbursement)
          end
        end

        private

        def amount_changed?(order)
          # We use `order.payment_total` to ensure we capture any total changes
          # from refunds.
          SuperGood::SolidusTaxjar.api.show_latest_transaction_for(order).amount !=
            (order.payment_total - order.additional_tax_total)
        end

        def completed_before_reporting_enabled?(order)
          configuration = SuperGood::SolidusTaxjar.configuration

          configuration.preferred_reporting_enabled &&
            configuration.preferred_reporting_enabled_at > order.completed_at
        end

        def reportable_order?(order)
          SuperGood::SolidusTaxjar.reportable_order_check.call(order)
        end

        def transaction_replaceable?(order)
          order.taxjar_order_transactions.present? && order.payment_state == "paid"
        end
        alias transaction_refundable? transaction_replaceable?

      end
    end
  end
end
