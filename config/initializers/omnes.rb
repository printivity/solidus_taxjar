Rails.application.config.to_prepare do
  %i[
    tax_exemption_created
    tax_exemption_updated
    tax_exemption_destroyed
    tax_exemption_customer_request
  ].each { |event_name| Spree::Bus.register(event_name) }
  SuperGood::SolidusTaxjar::Spree::ReportingSubscriber.new.subscribe_to(Spree::Bus)
  SuperGood::SolidusTaxjar::Spree::TaxExemptionsSubscriber.new.subscribe_to(Spree::Bus)
end