Rails.application.config.to_prepare do
  %i[
    shipment_shipped
    tax_exemption_created
    tax_exemption_updated
    tax_exemption_destroyed
    tax_exemption_approved
    tax_exemption_disapproved
    tax_exemption_customer_request
  ].each { |event_name| Spree::Bus.register(event_name) }
  SuperGood::SolidusTaxjar::Spree::TaxExemptionsSubscriber.new.subscribe_to(Spree::Bus)
end