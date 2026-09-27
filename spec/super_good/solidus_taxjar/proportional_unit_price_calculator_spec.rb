require "spec_helper"

RSpec.describe ::SuperGood::SolidusTaxjar::ProportionalUnitPriceCalculator do
  # Plain doubles keep these examples free of the host app's Shipment#address,
  # which Solidus core does not define.
  let(:line_item) { double("line_item", id: 33, quantity: 10, total: BigDecimal("100")) }
  let(:order) { double("order", line_items: [line_item], shipments: shipments) }

  def address(id)
    double("address", id: id)
  end

  def shipment(address, quantity)
    inventory_unit = double("inventory_unit", line_item_id: line_item.id, line_item: line_item, quantity: quantity)
    double("shipment", address: address, inventory_units: [inventory_unit])
  end

  subject(:unit_prices) { described_class.new(order).calculate }

  context "when one line item ships in two shipments to the same address" do
    let(:home) { address(1) }
    let(:shipments) { [shipment(home, 6), shipment(home, 4)] }

    it "prices the address's summed quantity at the line item's full total" do
      expect(unit_prices[33][1] * 10).to eq BigDecimal("100")
    end

    it "sends a TaxJar line whose unit price times quantity is the line item total" do
      inventory_units = shipments.flat_map(&:inventory_units)
      allow(line_item).to receive(:tax_category).and_return(nil)

      no_discount = { 33 => { 1 => BigDecimal("0") } }

      params = ::SuperGood::SolidusTaxjar::ApiParams.send(:order_line_items_params, home, inventory_units, no_discount, unit_prices)
      line = params[:line_items].first

      expect(line[:quantity]).to eq 10
      expect(line[:unit_price] * line[:quantity]).to eq BigDecimal("100")
    end
  end

  context "when the same-address shipments carry different rounded shares" do
    # $101.27 over 32 units: 1 + 1 + 30 as in the class comment, with the two single units at one address.
    let(:line_item) { double("line_item", id: 33, quantity: 32, total: BigDecimal("101.27")) }
    let(:home) { address(1) }
    let(:office) { address(2) }
    let(:shipments) { [shipment(home, 1), shipment(home, 1), shipment(office, 30)] }

    it "keeps the line item total across addresses" do
      # Unit prices keep full precision, so round the products back to cents.
      home_total = (unit_prices[33][1] * 2).round(2)
      office_total = (unit_prices[33][2] * 30).round(2)

      expect(home_total).to eq BigDecimal("6.33")
      expect(office_total).to eq BigDecimal("94.94")
      expect(home_total + office_total).to eq BigDecimal("101.27")
    end
  end

  context "when each address gets one shipment" do
    let(:shipments) { [shipment(address(1), 6), shipment(address(2), 4)] }

    it "prices each address by its own quantity" do
      expect(unit_prices).to eq(33 => { 1 => BigDecimal("10"), 2 => BigDecimal("10") })
    end
  end
end
