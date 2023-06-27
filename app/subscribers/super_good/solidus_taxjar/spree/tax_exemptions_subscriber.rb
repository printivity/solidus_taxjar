# frozen_string_literal: true

module SuperGood
  module SolidusTaxjar
    module Spree
      module TaxExemptionsSubscriber
        QUEUE_NAME = "taxjar"

        include Omnes::Subscriber

        handle :tax_exemption_created, with: :create_customer
        handle :tax_exemption_updated, with: :update_customer
        handle :tax_exemption_destroyed, with: :delete_customer
        handle :tax_exemption_customer_request, with: :send_notification_email
        handle :tax_exemption_approved, with: :send_approved_email
        handle :tax_exemption_disapproved, with: :send_disapproved_email

        def create_customer(event)
          user = event.payload[:user]
          SuperGood::SolidusTaxjar.api.create_customer_for(user) if eligible_tax_exemption(user)
        end

        def update_customer(event)
          user = event.payload[:user]
          customer = SuperGood::SolidusTaxjar.api.show_customer_for(user)
          if customer
            SuperGood::SolidusTaxjar.api.update_customer_for(user) if eligible_tax_exemption(user)
            SuperGood::SolidusTaxjar.api.delete_customer_for(user) if no_exemptions(user)
          else
            SuperGood::SolidusTaxjar.api.create_customer_for(user) if eligible_tax_exemption(user)
          end
        end

        def delete_customer(event)
          user = event.payload[:user]
          SuperGood::SolidusTaxjar.api.delete_customer_for(user)
        end

        def send_notification_email(event)
          user = event.payload[:user]
          SuperGood::SolidusTaxjar::TaxExemptionMailer.tax_exemption_request(user).deliver_now
        end

        def send_approved_email(event)
          user = event.payload[:user]
          state = event.payload[:state]
          SuperGood::SolidusTaxjar::TaxExemptionMailer.approved_email(user, state).deliver_now
        end

        def send_disapproved_email(event)
          user = event.payload[:user]
          state = event.payload[:state]
          SuperGood::SolidusTaxjar::TaxExemptionMailer.disapproved_email(user, state).deliver_now
        end

        private

        def eligible_tax_exemption(user)
          user.taxjar_customer&.taxjar_exempt_regions&.map(&:approved)&.any?
        end

        def no_exemptions(user)
          user.taxjar_customer&.taxjar_exempt_regions&.blank?
        end
      end
    end
  end
end
