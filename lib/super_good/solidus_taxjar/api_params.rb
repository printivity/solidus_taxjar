module SuperGood
  module SolidusTaxjar
    module ApiParams
      UNTAXABLE_INVENTORY_UNIT_STATES = ["returned", "canceled"]

      class << self
        def order_params(order, address, shipments)
          {}
            .merge(customer_id(order))
            .merge(order_address_params(address))
            .merge(line_items_params(shipments.map(&:inventory_units).flatten.compact))
            .merge(shipping: shipping(shipments))
            .merge(SuperGood::SolidusTaxjar.custom_order_params.call(order))
        end

        def address_params(address)
          [
            address.zipcode,
            {
              street: address.address1,
              city: address.city,
              state: address&.state&.abbr || address.state_name,
              country: address.country.iso
            }
          ]
        end

        def tax_rate_address_params(address)
          {
            amount: 100,
            shipping: 0
          }.merge(order_address_params(address))
        end

        def transaction_params(order, address, shipments, transaction_id = order.number)
          {}.merge(customer_id(order))
             .merge(order_address_params(address))
             .merge(line_items_params(shipments.map(&:inventory_units).flatten.compact))
             .merge(shipping: shipping(shipments))
             .merge(SuperGood::SolidusTaxjar.custom_order_params.call(order))

          {}
            .merge(customer_id(order))
            .merge(order_address_params(address))
            .merge(transaction_line_items_params(address, shipments.map(&:inventory_units).flatten.compact))
            .merge(
              transaction_id: transaction_id,
              transaction_date: order.completed_at.to_formatted_s(:iso8601),
              amount: order_total_for_shipments(shipments) - reimbursement_total_without_tax(shipments),
              shipping: shipping(shipments),
              sales_tax: sales_tax(order, address, shipments)
            )
        end

        def refund_transaction_params(spree_order, taxjar_order)
          {}
            .merge(order_address_params(spree_order.tax_address))
            .merge(
              {
                transaction_id: TransactionIdGenerator.refund_transaction_id(taxjar_order.transaction_id),
                transaction_reference_id: taxjar_order.transaction_id,
                transaction_date: spree_order.completed_at.to_formatted_s(:iso8601),
                amount: -1 * taxjar_order.amount,
                sales_tax: -1 * taxjar_order.sales_tax,
                shipping: -1 * taxjar_order.shipping,
                line_items: taxjar_order.line_items.map { |line_item|
                  line_item.to_h.merge({
                    unit_price: line_item.unit_price * -1,
                    discount:  line_item.discount * -1,
                    sales_tax: line_item.sales_tax * -1
                  })
                }
              }
            )
        end

        def refund_params(reimbursement)
          additional_taxes = reimbursement.return_items.sum(&:additional_tax_total)

          {}
            .merge(order_address_params(reimbursement.order.tax_address))
            .merge(
              transaction_id: reimbursement.number,
              transaction_reference_id: reimbursement.order.number,
              transaction_date: reimbursement.order.completed_at.to_formatted_s(:iso8601),
              amount: reimbursement.total - additional_taxes,
              shipping: 0,
              sales_tax: additional_taxes
            )
        end

        def validate_address_params(spree_address, include_street = true)
          params = {
            country: spree_address.country&.iso,
            state: spree_address.state&.abbr || spree_address.state_name,
            zip: spree_address.zipcode,
            city: spree_address.city,
          }
          params[:street] = [spree_address.address1, spree_address.address2].compact.join(' ') if include_street
          params
        end

        def customer_params(customer)
          address = customer.address

          {
            customer_id: customer.user_id,
            exemption_type: customer.tax_exemption_type,
            name: address.company.present? ? address.company : address.name,
            country: address.country.iso,
            state: address.state.abbr,
            zip: address.zipcode,
            city: address.city,
            street: address.address1,
            exempt_regions: customer.taxjar_exempt_regions.approved.map do |exempt_region|
              state = exempt_region.state

              {
                state: state.abbr,
                country: state.country.iso
              }
            end
          }
        end

        private

        def customer_id(order)
          return {} unless order.user_id

          {customer_id: order.user_id.to_s}
        end

        def order_address_params(address)
          {
            to_country: address.country.iso,
            to_zip: address.zipcode,
            to_city: address.city,
            to_state: address&.state&.abbr || address.state_name,
            to_street: address.address1
          }
        end

        # @private
        # This method builds line item parameters as expected by the TaxJar
        # Tax API.
        #
        # @param line_items [Spree::LineItem::ActiveRecord_Relation] All of the
        #   order's line items.
        # @return [Hash] A TaxJar API-friendly line item collection.
        def line_items_params(_inventory_units)
          grouped_inventory_units = _inventory_units.group_by(&:line_item)

          line_items = grouped_inventory_units.filter_map { |line_item, inventory_units|
            quantity = inventory_units.sum(&:quantity)

            next unless quantity.positive?

            {
              id: line_item.id,
              quantity:,
              unit_price: line_item.total / line_item.quantity,
              discount: discount(line_item) * (quantity / line_item.quantity.to_f),
              product_tax_code: line_item.tax_category&.tax_code
            }
          }

          { line_items: }
        end

        # @private
        # This method builds line item parameters as expected by the TaxJar
        # Transactions API. Note that this logic different from
        # `.line_item_params` as it excludes inventory units we consider to be
        # untaxable (i.e. returned or cancelled inventory units).
        #
        # @param line_items [Spree::LineItem::ActiveRecord_Relation] All of the
        #   order's line items.
        # @return [Hash] A TaxJar API-friendly line item collection.
        def transaction_line_items_params(address, _inventory_units)
          grouped_inventory_units = _inventory_units.group_by(&:line_item)

          line_items = grouped_inventory_units.filter_map { |line_item, inventory_units|
            quantity = taxable_quantity(inventory_units)

            next unless quantity.positive?

            {
              id: line_item.id,
              quantity:,
              product_identifier: line_item.sku,
              unit_price: line_item.total / line_item.quantity,
              discount: discount(line_item) * (quantity / line_item.quantity.to_f),
              product_tax_code: line_item.tax_category&.tax_code,
              description: line_item.variant.descriptive_name,
              sales_tax: line_item_sales_tax(line_item, address, inventory_units)
            }
          }

          { line_items: }
        end

        def discount(line_item)
          ::SuperGood::SolidusTaxjar.discount_calculator.new(line_item).discount
        end

        def shipping(shipments)
          SuperGood::SolidusTaxjar.shipping_calculator.call(shipments)
        end

        def sales_tax(order, address, shipments)
          return 0 if order.total.zero?

          tax_total = order.all_adjustments.tax.
            select { |adjustment| adjustment.label.include?(address.address1) }.sum(&:amount)

          round_to_two_places(tax_total - reimbursement_tax_total(shipments))
        end

        def line_item_sales_tax(line_item, address, inventory_units)
          return 0 if line_item.order.total.zero?

          tax_total = line_item.adjustments.tax.
            select { |adjustment| adjustment.label.include?(address.address1) }.sum(&:amount)

          round_to_two_places(tax_total -  line_item_reimbursement_tax_total(inventory_units))
        end

        def round_to_two_places(amount)
          BigDecimal(amount.to_s).round(2, BigDecimal::ROUND_HALF_UP)
        end

        def taxable_inventory(inventory_units)
          inventory_units.reject {|i| UNTAXABLE_INVENTORY_UNIT_STATES.include?(i.state)}
        end

        def taxable_quantity(inventory_units)
          taxable_inventory(inventory_units).sum(&:quantity)
        end

        def line_item_reimbursement_tax_total(inventory_units)
          inventory_units
            .flat_map(&:return_items)
            .filter { |return_item| return_item.reimbursement.present? }
            .sum(&:additional_tax_total)
        end

        def reimbursement_tax_total(shipments)
          inventory_units = shipments.map(&:inventory_units).flatten.compact
          inventory_units.flat_map(&:return_items)
                         .filter { |return_item| return_item.reimbursement.present? }
                         .sum(&:additional_tax_total)
        end

        def reimbursement_total_without_tax(shipments)
          inventory_units = shipments.map(&:inventory_units).flatten.compact
          inventory_units.flat_map(&:return_items)
                         .filter { |return_item| return_item.reimbursement.present? }
                         .sum(&:amount)
        end

        def order_total_for_shipments(shipments)
          grouped_inventory_units = shipments.map(&:inventory_units).flatten.compact.group_by(&:line_item)

          line_items_total = grouped_inventory_units.filter_map { |line_item, inventory_units|
            quantity = inventory_units.sum(&:quantity)
            next unless quantity.positive?

            (line_item.total - discount(line_item)) * (quantity / line_item.quantity.to_f)
          }.sum

          line_items_total + shipping(shipments)
        end
      end
    end
  end
end
