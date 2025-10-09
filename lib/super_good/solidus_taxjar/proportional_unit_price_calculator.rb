# frozen_string_literal: true

module SuperGood
  module SolidusTaxjar
    # Calculates proportional line item unit prices across multiple shipments with proper rounding.
    #
    # When line items have high-precision prices and are split across multiple shipments,
    # unit prices need to be calculated such that the sum of (unit_price * quantity) for all
    # shipments equals the line item total. This calculator ensures that rounding errors
    # don't accumulate by distributing the rounding error one cent at a time across shipments.
    #
    # @example Basic usage
    #   calculator = ProportionalUnitPriceCalculator.new(order)
    #   adjustments = calculator.calculate
    #   # => { line_item_id => { address_id => unit_price } }
    #
    # @example With rounding distribution
    #   # Line item total: $101.27, quantity: 32
    #   # Shipment 1: 1 unit  -> proportional total $3.16 -> unit_price $3.17 (after rounding adjustment)
    #   # Shipment 2: 1 unit  -> proportional total $3.16 -> unit_price $3.16
    #   # Shipment 3: 30 units -> proportional total $94.94 -> unit_price $3.1646...
    #   # Sum: $3.17 + $3.16 + $94.94 = $101.27 ✓
    class ProportionalUnitPriceCalculator
      # @param order [Spree::Order] The order to calculate unit prices for
      def initialize(order)
        @order = order
      end

      # Calculate proportional line item unit prices for all shipments.
      #
      # This method ensures that when line item totals are split proportionally across shipments,
      # the rounding errors are distributed evenly. Each proportional total is initially calculated
      # and rounded. Then the rounding error (difference between sum of rounded proportional totals
      # and line item total) is distributed one cent at a time to shipments until the error is zero.
      #
      # @return [Hash] Nested hash: { line_item_id => { address_id => unit_price } }
      def calculate
        @order.line_items.each_with_object({}) do |line_item, adjustments|
          adjustment = calculate_line_item_unit_prices(line_item)
          adjustments[line_item.id] = adjustment if adjustment
        end
      end

      # Calculate simple proportional unit price for a line item in a shipment.
      #
      # @param line_item [Spree::LineItem] The line item
      # @param quantity [Integer] The quantity in the shipment
      # @return [BigDecimal] The proportional unit price (not rounded to 2 decimals)
      def proportional_unit_price(line_item, quantity)
        return BigDecimal('0') if line_item.total.zero? || line_item.quantity.zero?

        proportion = BigDecimal(quantity) / BigDecimal(line_item.quantity)
        proportional_total = line_item.total * proportion

        # Return unit price (not rounded to 2 decimals)
        proportional_total / quantity
      end

      private

      def calculate_line_item_unit_prices(line_item)
        shipment_quantities = gather_shipment_quantities(line_item)
        return nil if shipment_quantities.empty?

        # Calculate proportional totals (rounded to 2 decimals)
        proportional_data = calculate_proportional_totals(line_item, shipment_quantities)
        
        # Distribute rounding error evenly across shipments
        distribute_rounding_error!(proportional_data, line_item.total)
        
        # Calculate unit prices from adjusted proportional totals
        calculate_unit_prices_from_totals(proportional_data)
        
        build_unit_prices_hash(proportional_data)
      end

      def gather_shipment_quantities(line_item)
        @order.shipments.filter_map do |shipment|
          inventory_units = shipment.inventory_units.select { |iu| iu.line_item_id == line_item.id }
          quantity = inventory_units.sum(&:quantity)
          next unless quantity.positive?

          { address_id: shipment.address.id, quantity: quantity }
        end
      end

      def calculate_proportional_totals(line_item, shipment_quantities)
        total_quantity = line_item.quantity
        
        shipment_quantities.map do |sq|
          proportion = BigDecimal(sq[:quantity]) / BigDecimal(total_quantity)
          proportional_total = line_item.total * proportion
          rounded_total = round_to_two_places(proportional_total)
          
          sq.merge(proportional_total: rounded_total)
        end
      end

      def distribute_rounding_error!(proportional_data, line_item_total)
        return if proportional_data.empty?

        sum_of_totals = proportional_data.sum { |pd| pd[:proportional_total] }
        rounding_error_cents = ((line_item_total - sum_of_totals) * 100).round
        
        return if rounding_error_cents.zero?

        # Distribute error one cent at a time
        # Start from the first shipment and cycle through
        cent = BigDecimal('0.01')
        direction = rounding_error_cents.positive? ? 1 : -1
        abs_error_cents = rounding_error_cents.abs
        
        abs_error_cents.times do |i|
          index = i % proportional_data.length
          proportional_data[index][:proportional_total] += (cent * direction)
        end
      end

      def calculate_unit_prices_from_totals(proportional_data)
        proportional_data.each do |pd|
          # Calculate unit price from adjusted proportional total
          # Don't round to 2 decimals - keep full precision
          pd[:unit_price] = pd[:proportional_total] / pd[:quantity]
        end
      end

      def build_unit_prices_hash(proportional_data)
        proportional_data.each_with_object({}) do |pd, hash|
          hash[pd[:address_id]] = pd[:unit_price]
        end
      end

      def round_to_two_places(amount)
        BigDecimal(amount.to_s).round(2, BigDecimal::ROUND_HALF_UP)
      end
    end
  end
end

