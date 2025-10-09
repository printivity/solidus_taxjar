module SuperGood
  module SolidusTaxjar
    # Calculates proportional discounts across multiple shipments with proper rounding.
    #
    # When an order has discounts and multiple shipments, discounts need to be
    # distributed proportionally. This calculator ensures that rounding errors
    # don't accumulate by adjusting the last shipment to absorb any difference.
    #
    # @example Basic usage
    #   calculator = ProportionalDiscountCalculator.new(order, discount_calculator)
    #   adjustments = calculator.calculate
    #   # => { line_item_id => { address_id => discount_amount } }
    class ProportionalDiscountCalculator
      # @param order [Spree::Order] The order to calculate discounts for
      # @param discount_calculator [#call] Callable that returns discount for a line item
      def initialize(order, discount_calculator = nil)
        @order = order
        @discount_calculator = discount_calculator || default_discount_calculator
      end

      # Calculate discount adjustments for all line items across all shipments.
      #
      # This method ensures that when discounts are split proportionally across shipments,
      # the rounding errors don't accumulate. The last shipment for each line item absorbs
      # any rounding difference.
      #
      # @return [Hash] Nested hash: { line_item_id => { address_id => discount_amount } }
      def calculate
        @order.line_items.each_with_object({}) do |line_item, adjustments|
          adjustment = calculate_line_item_adjustments(line_item)
          adjustments[line_item.id] = adjustment if adjustment
        end
      end

      # Calculate simple proportional discount for a line item in a shipment.
      #
      # This is used as a fallback when pre-calculated adjustments are not available.
      #
      # @param line_item [Spree::LineItem] The line item
      # @param quantity [Integer] The quantity in the shipment
      # @return [BigDecimal] The proportional discount amount
      def proportional_discount(line_item, quantity)
        total_discount = line_item_discount(line_item)
        return BigDecimal("0") if total_discount.zero? || line_item.quantity.zero?

        proportion = quantity / line_item.quantity.to_f
        proportional_amount = total_discount * proportion

        round_to_two_places(proportional_amount)
      end

      private

      def calculate_line_item_adjustments(line_item)
        total_discount = line_item_discount(line_item)
        return nil if total_discount.zero?

        shipment_quantities = gather_shipment_quantities(line_item)
        return nil if shipment_quantities.empty?

        proportional_discounts = calculate_proportional_discounts(line_item, total_discount, shipment_quantities)
        adjust_for_rounding_error!(proportional_discounts, total_discount)
        build_adjustments_hash(proportional_discounts)
      end

      def line_item_discount(line_item)
        @discount_calculator.call(line_item)
      end

      def gather_shipment_quantities(line_item)
        @order.shipments.filter_map do |shipment|
          inventory_units = shipment.inventory_units.select { |iu| iu.line_item_id == line_item.id }
          quantity = inventory_units.sum(&:quantity)
          next unless quantity.positive?

          { address_id: shipment.address.id, quantity: quantity }
        end
      end

      def calculate_proportional_discounts(line_item, total_discount, shipment_quantities)
        shipment_quantities.map do |sq|
          proportion = sq[:quantity] / line_item.quantity.to_f
          rounded_discount = round_to_two_places(total_discount * proportion)
          sq.merge(discount: rounded_discount)
        end
      end

      def adjust_for_rounding_error!(proportional_discounts, total_discount)
        return if proportional_discounts.empty?

        sum_of_discounts = proportional_discounts.sum { |pd| pd[:discount] }
        rounding_error = round_to_two_places(total_discount - sum_of_discounts)

        if rounding_error != 0
          # Add the rounding error to the last shipment
          proportional_discounts.last[:discount] = round_to_two_places(
            proportional_discounts.last[:discount] + rounding_error
          )
        end
      end

      def build_adjustments_hash(proportional_discounts)
        proportional_discounts.each_with_object({}) do |pd, hash|
          hash[pd[:address_id]] = pd[:discount]
        end
      end

      def round_to_two_places(amount)
        BigDecimal(amount.to_s).round(2, BigDecimal::ROUND_HALF_UP)
      end

      def default_discount_calculator
        ->(line_item) { ::SuperGood::SolidusTaxjar.discount_calculator.new(line_item).discount }
      end
    end
  end
end

