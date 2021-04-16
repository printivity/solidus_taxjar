module SuperGood
  module SolidusTaxjar
    class TaxRateCalculator
      include CalculatorHelper
      def initialize(address, api: SuperGood::SolidusTaxjar.api)
        @address = address
        @api = api
      end

      def calculate
        return no_rate if SuperGood::SolidusTaxjar.test_mode
        return no_rate if incomplete_address?(address)
        return no_rate unless taxable_address?(address)
        cache do
          api.tax_rate_for(address).to_d
        end
      rescue StandardError, Rack::Timeout::RequestTimeoutException => e
        exception_handler.call(e)
        ::SuperGood::SolidusTaxJar.fallback_tax_rate_calculator.call(address) || no_rate
      end

      private

      attr_reader :address, :api

      def no_rate
        BigDecimal(0)
      end

      def cache_key
        SuperGood::SolidusTaxjar.cache_key.call(address)
      end
    end
  end
end
