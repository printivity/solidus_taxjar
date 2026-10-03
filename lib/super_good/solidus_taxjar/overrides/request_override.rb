module SuperGood
  module SolidusTaxjar
    module RequestOverride
      def build_http_client
        if SuperGood::SolidusTaxjar.logging_enabled
          super.use(logging: {logger: SuperGood::SolidusTaxjar.logger})
        else
          super
        end
      end

      private

      # taxjar-ruby only takes a timeout from each call's own params and otherwise builds the
      # HTTP client with nil timeouts. A client built by Api.default_taxjar_client carries
      # connect, write and read timeouts; use them unless the call passed its own timeout.
      def set_http_timeout
        client_timeouts = client.get_api_config("http_timeouts")
        per_call_timeout = @options[:timeout]

        if client_timeouts && (per_call_timeout.nil? || per_call_timeout == "")
          @http_timeout = client_timeouts
        else
          super
        end
      end

      Taxjar::API::Request.prepend(self)
    end
  end
end
