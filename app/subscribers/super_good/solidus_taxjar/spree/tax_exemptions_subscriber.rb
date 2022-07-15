# frozen_string_literal: true

require "spree/event/subscriber"

module Mgx
  module TaxExemptionsSubscriber
    QUEUE_NAME = "taxjar"

    include Spree::Event::Subscriber

    event_action :create_customer, event_name: :tax_exemption_created
    event_action :update_customer, event_name: :tax_exemption_updated
    event_action :delete_customer, event_name: :tax_exemption_destroyed
    event_action :send_notification_email, event_name: :tax_exemption_customer_request
    event_action :send_approved_email, event_name: :tax_exemption_approved
    event_action :send_disapproved_email, event_name: :tax_exemption_disapproved

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
      Mgx::ContactUsMailer.tax_exemption_request(user).deliver_now
    end

    def send_approved_email(event)
      user = event.payload[:user]
      state = event.payload[:state]
      Mgx::TaxExemptionMailer.approved_email(user, state).deliver_now
    end

    def send_disapproved_email(event)
      user = event.payload[:user]
      state = event.payload[:state]
      Mgx::TaxExemptionMailer.disapproved_email(user, state).deliver_now
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
