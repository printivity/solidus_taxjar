module SuperGood
  module SolidusTaxjar
    class TaxExemptionMailer < BaseMailer
      def approved_email(user, state)
        @user = user
        @state = state
        @store = Spree::Store.default

        mail(to: @user.email,
             subject: "Your tax exemption request for #{@state.abbr} has been approved",
             from: from_address(@store))
      end

      def disapproved_email(user, state)
        @user = user
        @state = state
        @store = Spree::Store.default

        mail(to: @user.email,
             subject: "Your tax exemption request for #{@state.abbr} has not been approved",
             from: from_address(@store))
      end
    end
  end
end
