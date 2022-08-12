module SuperGood
  module SolidusTaxjar
    class TaxExemptionMailer < ApplicationMailer

      def tax_exemption_request(user)
        @user = user
        mail(to: SuperGood::SolidusTaxjar.tax_exemption_mailer_address,
           subject: format('[TAX EXEMPTION REQUEST] Tax exemption request for ("%s")',
                           @user.email),
           from: from_address(@store),
           reply_to: @user.email)
      end

      def approved_email(user, state)
        @user = user
        @state = state
        @store = ::Spree::Store.default

        mail(to: @user.email,
          subject: "Your tax exemption request for #{@state.abbr} has been approved",
          from: from_address(@store))
      end

      def disapproved_email(user, state)
        @user = user
        @state = state
        @store = ::Spree::Store.default

        mail(to: @user.email,
          subject: "Your tax exemption request for #{@state.abbr} has not been approved",
          from: from_address(@store))
      end
    end
  end
end
