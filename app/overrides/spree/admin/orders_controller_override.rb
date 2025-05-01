module Spree
  module Admin
    module OrdersControllerOverride
      # FIXME: Move this to TaxJar transactions controller.
      def taxjar_transactions
        load_order
      end

      def need_taxes_filed
        # ADNAN: find all orders that have not been submitted to taxjar that need taxes files. regardless of whether
        # its an automatic or manual filing

        @reasons = {}

        @orders = Spree::Order.includes(:store, :taxjar_order_transactions, :taxjar_transaction_sync_logs, :user,
                                        :line_items).
          where(type: [Spree::Order, Mgx::Order::Reorder]).
          where(state: "order_complete").
          where("completed_at >= ?", SuperGood::SolidusTaxjar.configuration.preferred_reporting_enabled_at).
          select { |o| o.taxjar_order_transactions.blank? || o.taxjar_transaction_sync_logs&.last&.status == 'error' }

        @orders.each do |o|
          if !SuperGood::SolidusTaxjar.reportable_order_check.call(o)
            @reasons[o.number] = "Order must be filed Manually"
          else
            @reasons[o.number] = o.taxjar_transaction_sync_logs&.last&.error_message
          end
        end
      end

      Spree::Admin::OrdersController.prepend self
    end
  end
end
