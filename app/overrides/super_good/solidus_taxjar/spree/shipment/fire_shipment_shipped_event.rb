# frozen_string_literal: true

module SuperGood
  module SolidusTaxjar
    module Spree
      module Shipment
        module FireShipmentShippedEvent
          def after_ship
            ::Spree::Event.fire 'shipment_shipped', shipment: self
            logger.debug "shipment shipped event triggered"
            super
          end

          ::Spree::Shipment.prepend(self)
        end
      end
    end
  end
end
