require "spec_helper"

RSpec.describe ::SuperGood::SolidusTaxjar::ProportionalDiscountCalculator do
  # Plain doubles keep these examples free of the host app's Shipment#address,
  # which Solidus core does not define.
  let(:line_item) { double("line_item", id: 33, quantity: 10, total: BigDecimal("100")) }
  let(:discount_calculator) { ->(_line_item) { BigDecimal("10") } }
  let(:order) { double("order", line_items: [line_item], shipments: shipments) }

  def address(id)
    double("address", id: id)
  end

  def shipment(address, quantity)
    inventory_unit = double("inventory_unit", line_item_id: line_item.id, line_item: line_item, quantity: quantity)
    double("shipment", address: address, inventory_units: [inventory_unit])
  end

  subject(:adjustments) { described_class.new(order, discount_calculator).calculate }

  context "when one line item ships in two shipments to the same address" do
    let(:home) { address(1) }
    let(:shipments) { [shipment(home, 6), shipment(home, 4)] }

    it "sends the whole discount for that address, not the last shipment's share" do
      expect(adjustments).to eq(33 => { 1 => BigDecimal("10") })
    end

    it "sends the summed discount on the TaxJar line item for that address" do
      inventory_units = shipments.flat_map(&:inventory_units)
      allow(line_item).to receive(:tax_category).and_return(nil)

      unit_prices = ::SuperGood::SolidusTaxjar::ProportionalUnitPriceCalculator.new(order).calculate

      params = ::SuperGood::SolidusTaxjar::ApiParams.send(:order_line_items_params, home, inventory_units, adjustments, unit_prices)

      expect(params[:line_items].size).to eq 1
      expect(params[:line_items].first).to include(id: 33, quantity: 10, discount: BigDecimal("10"))
    end
  end

  context "when one line item ships to two addresses, one of them in two shipments" do
    let(:home) { address(1) }
    let(:office) { address(2) }
    let(:shipments) { [shipment(home, 3), shipment(office, 3), shipment(home, 4)] }

    it "sums the shipments per address and keeps the discount total" do
      expect(adjustments).to eq(33 => { 1 => BigDecimal("7"), 2 => BigDecimal("3") })
      expect(adjustments[33].values.sum).to eq BigDecimal("10")
    end
  end

  context "when the split needs a rounding cent" do
    let(:line_item) { double("line_item", id: 33, quantity: 3, total: BigDecimal("30")) }
    let(:home) { address(1) }
    let(:office) { address(2) }
    let(:shipments) { [shipment(home, 1), shipment(home, 1), shipment(office, 1)] }

    it "keeps the rounding cent and the discount total" do
      # $10 / 3 = 3.33 each, plus one rounding cent on the first shipment.
      expect(adjustments).to eq(33 => { 1 => BigDecimal("6.67"), 2 => BigDecimal("3.33") })
    end
  end

  context "when each address gets one shipment" do
    let(:shipments) { [shipment(address(1), 6), shipment(address(2), 4)] }

    it "splits the discount by quantity" do
      expect(adjustments).to eq(33 => { 1 => BigDecimal("6"), 2 => BigDecimal("4") })
    end
  end
end
