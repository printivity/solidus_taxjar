require "solidus_core"
require "solidus_support"
require "deface"
require "taxjar"
require "super_good/solidus_taxjar/overrides/request_override"

require "super_good/solidus_taxjar/version"
require "super_good/solidus_taxjar/transaction_id_generator"
require "super_good/solidus_taxjar/api_params"
require "super_good/solidus_taxjar/api"
require "super_good/solidus_taxjar/cached_api"
require "super_good/solidus_taxjar/calculator_helper"
require "super_good/solidus_taxjar/tax_calculator"
require "super_good/solidus_taxjar/tax_rate_calculator"
require "super_good/solidus_taxjar/discount_calculator"
require "super_good/solidus_taxjar/proportional_discount_calculator"
require "super_good/solidus_taxjar/proportional_unit_price_calculator"
require "super_good/solidus_taxjar/addresses"
require "super_good/solidus_taxjar/reporting"
require "super_good/solidus_taxjar/reportable"
require "super_good/solidus_taxjar/backfill_transactions"

module SuperGood
  module SolidusTaxjar
    class << self
      attr_accessor :cache_duration
      attr_accessor :cache_key
      attr_accessor :customer_email_enabled
      attr_accessor :custom_order_params
      attr_accessor :discount_calculator
      attr_accessor :exception_handler
      attr_accessor :http_timeouts
      attr_accessor :job_queue
      attr_accessor :line_item_tax_label_maker
      attr_accessor :line_item_unit_price_calculator
      attr_accessor :logging_enabled
      attr_accessor :reportable_order_check
      attr_accessor :reporting_ui_enabled
      attr_accessor :shipping_calculator
      attr_accessor :shipping_tax_label_maker
      attr_accessor :tax_exemption_mailer_from_address
      attr_accessor :tax_exemption_mailer_to_address
      attr_accessor :taxable_address_check
      attr_accessor :taxable_order_check
      attr_accessor :test_mode
      attr_writer :logger

      def configuration
        ::SuperGood::SolidusTaxjar::Configuration.default
      end

      def api
        ::SuperGood::SolidusTaxjar::Api.new
      end

      def table_name_prefix
        "solidus_taxjar_"
      end

      def reporting
        ::SuperGood::SolidusTaxjar::Reporting.new
      end

      def logger
        @logger || Rails.logger
      end
    end

    self.cache_duration = 3.hours
    self.cache_key = ->(record) {
      record_type = record.class.name.demodulize.underscore
      ApiParams.send("#{record_type}_params", record).to_json
    }
    self.customer_email_enabled = ->(_user) { true }
    self.custom_order_params = ->(order) { {} }
    self.discount_calculator = ::SuperGood::SolidusTaxjar::DiscountCalculator
    self.exception_handler = ->(e) {
      logger.error "An error occurred while fetching TaxJar tax rates - #{e}: #{e.message}"
    }
    # Seconds allowed for each phase of a TaxJar HTTP call. Tax is fetched inside the checkout
    # request, once per shipping address, so a TaxJar call with no timeout holds that request
    # open for as long as TaxJar takes to answer. A call that runs past these limits raises
    # Taxjar::Error, which the tax calculator reports through exception_handler.
    #
    # These are per socket operation (the http gem's per-operation timeouts), not a total.
    self.http_timeouts = {connect: 2, write: 5, read: 8}
    self.job_queue = :default
    self.line_item_tax_label_maker = ->(taxjar_line_item, spree_line_item) { "Sales Tax" }
    self.line_item_unit_price_calculator = ->(spree_line_item) { spree_line_item.price }
    self.logging_enabled = false

    self.reportable_order_check = ->(order) { true }

    self.shipping_calculator = ->(shipments) { shipments.sum(&:cost) }
    self.shipping_tax_label_maker = ->(taxjar_shipment, shipment) { "Sales Tax" }
    self.tax_exemption_mailer_from_address = "admin@example.com"
    self.tax_exemption_mailer_to_address = "admin@example.com"
    self.taxable_address_check = ->(address) { true }
    self.taxable_order_check = ->(order) { true }
    self.test_mode = false
  end
end
