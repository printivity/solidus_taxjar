# frozen_string_literal: true

module SuperGood
  module SolidusTaxjar
    # Calculates proportional line item amounts across multiple shipments with proper rounding.
    #
    # When line items have high-precision prices and are split across multiple shipments,
    # amounts need to be distributed proportionally. This calculator ensures that rounding
    # errors don't accumulate by adjusting the last shipment to absorb any difference.
    #
    # @example Basic usage
    #   calculator = ProportionalAmountCalculator.new(order)
    #   adjustments = calculator.calculate
    #   # => { line_item_id => { address_id => amount } }
    class ProportionalAmountCalculator

      # @param order [Spree::Order] The order to calculate amounts for
      def initialize(order)
        @order = order
      end

      # Calculate proportional line item amounts for all shipments.
      #
      # This method ensures that when line item totals are split proportionally across shipments,
      # the rounding errors don't accumulate. The last shipment for each line item absorbs
      # any rounding difference.
      #
      # @return [Hash] Nested hash: { line_item_id => { address_id => amount } }
      def calculate
        @order.line_items.each_with_object({}) do |line_item, adjustments|
          adjustment = calculate_line_item_amounts(line_item)
          adjustments[line_item.id] = adjustment if adjustment
        end
      end

      # Calculate simple proportional amount for a line item in a shipment.
      #
      # @param line_item [Spree::LineItem] The line item
      # @param quantity [Integer] The quantity in the shipment
      # @return [BigDecimal] The proportional amount
      def proportional_amount(line_item, quantity)
        return BigDecimal('0') if line_item.total.zero? || line_item.quantity.zero?

        proportion = quantity / line_item.quantity.to_f
        proportional_amt = line_item.total * proportion

        round_to_two_places(proportional_amt)
      end

      private

      def calculate_line_item_amounts(line_item)
        shipment_quantities = gather_shipment_quantities(line_item)
        return nil if shipment_quantities.empty?

        # Calculate the effective total based on taxable units only
        total_taxable_quantity = shipment_quantities.sum { |sq| sq[:quantity] }
        effective_total = (line_item.total / line_item.quantity) * total_taxable_quantity

        proportional_amounts = calculate_proportional_amounts(line_item, shipment_quantities, effective_total,
                                                              total_taxable_quantity)
        adjust_for_rounding_error!(proportional_amounts, effective_total)
        build_amounts_hash(proportional_amounts)
      end

      def gather_shipment_quantities(line_item)
        @order.shipments.filter_map do |shipment|
          inventory_units = shipment.inventory_units.select { |iu| iu.line_item_id == line_item.id }
          quantity = inventory_units.sum(&:quantity)
          next unless quantity.positive?

          { address_id: shipment.address.id, quantity: quantity }
        end
      end

      def calculate_proportional_amounts(_line_item, shipment_quantities, effective_total, total_taxable_quantity)
        shipment_quantities.map do |sq|
          proportion = sq[:quantity] / total_taxable_quantity.to_f
          rounded_amount = round_to_two_places(effective_total * proportion)
          sq.merge(amount: rounded_amount)
        end
      end

      def adjust_for_rounding_error!(proportional_amounts, total_amount)
        return if proportional_amounts.empty?

        sum_of_amounts = proportional_amounts.sum { |pa| pa[:amount] }
        rounding_error = round_to_two_places(total_amount - sum_of_amounts)
        return unless rounding_error != 0

        # Add the rounding error to the last shipment
        proportional_amounts.last[:amount] = round_to_two_places(
          proportional_amounts.last[:amount] + rounding_error
        )
      end

      def build_amounts_hash(proportional_amounts)
        proportional_amounts.each_with_object({}) do |pa, hash|
          hash[pa[:address_id]] = pa[:amount]
        end
      end

      def round_to_two_places(amount)
        BigDecimal(amount.to_s).round(2, BigDecimal::ROUND_HALF_UP)
      end
    end
  end
end
