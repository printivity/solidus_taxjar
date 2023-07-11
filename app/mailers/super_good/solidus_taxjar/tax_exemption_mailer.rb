module SuperGood
  module SolidusTaxjar
    class TaxExemptionMailer < ApplicationMailer

      def tax_exemption_request(user)
        @user = user
        @store = ::Spree::Store.default

        mail(to: SuperGood::SolidusTaxjar.tax_exemption_mailer_to_address,
           subject: format('[TAX EXEMPTION REQUEST] Tax exemption request for ("%s")',
                           @user.email),
           from: SuperGood::SolidusTaxjar.tax_exemption_mailer_from_address,
           reply_to: @user.email)
      end

      def approved_email(user, state)
        @user = user
        @state = state
        @store = ::Spree::Store.default

        mail(to: @user.email,
          subject: "Your tax exemption request for #{@state.abbr} has been approved",
          from: SuperGood::SolidusTaxjar.tax_exemption_mailer_from_address)
      end

      def disapproved_email(user, state)
        @user = user
        @state = state
        @store = ::Spree::Store.default

        mail(to: @user.email,
          subject: "Your tax exemption request for #{@state.abbr} has not been approved",
          from: SuperGood::SolidusTaxjar.tax_exemption_mailer_from_address)
      end

      def from_address(store)
        store.mail_from_address
      end
    end
  end
end
