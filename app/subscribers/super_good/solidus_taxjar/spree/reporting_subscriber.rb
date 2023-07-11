module SuperGood
  module SolidusTaxjar
    module Spree
      module ReportingSubscriber
        include ::Spree::Event::Subscriber

        if ::Spree::Event.method_defined?(:register)
          ::Spree::Event.register("shipment_shipped")
        end

        event_action :report_transaction, event_name: :shipment_shipped
        event_action :replace_transaction, event_name: :order_recalculated
        event_action :create_refund, event_name: :reimbursement_reimbursed

        def report_transaction(event)
          shipment = event.payload[:shipment]
          order = shipment.order

          return unless SuperGood::SolidusTaxjar.configuration.preferred_reporting_enabled

          if reportable_order?(order)
            SuperGood::SolidusTaxjar::ReportTransactionJob.perform_later(order)
          end
        end

        def replace_transaction(event)
          order = event.payload[:order]

          return unless SuperGood::SolidusTaxjar.configuration.preferred_reporting_enabled

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
          SuperGood::SolidusTaxjar.api.show_latest_transaction_for(order).amount !=
            (order.total - order.additional_tax_total)
        end

        def reportable_order?(order)
          SuperGood::SolidusTaxjar.reportable_order_check.call(order)
        end

        def transaction_replaceable?(order)
          order.taxjar_order_transactions.present? &&
            order.complete? &&
              order.payment_state == "paid"
        end
        alias transaction_refundable? transaction_replaceable?

      end
    end
  end
end
