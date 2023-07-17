# frozen_string_literal: true

module SuperGood
  module SolidusTaxjar
    module Spree
      module ShipmentDecorator
        def after_ship
          Spree::Bus.publish :shipment_shipped, shipment: self

          super
        end

        ::Spree::Shipment.prepend(self)
      end
    end
  end
end
