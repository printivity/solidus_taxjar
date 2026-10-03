require "spec_helper"

# One TaxJar call is made per shipping address. These examples cover what happens
# when some of those calls fail. Plain doubles stand in for the host app's
# Shipment#address, which Solidus core does not define.
RSpec.describe ::SuperGood::SolidusTaxjar::TaxCalculator, "when a TaxJar call fails for one address group" do
  subject(:order_tax) { described_class.new(order, api: api).calculate }

  let(:api) { instance_double(::SuperGood::SolidusTaxjar::Api) }
  let(:order) { double("order", id: 10, number: "R100000001", shipments: [home_shipment, office_shipment]) }

  let(:home) { address(1, "IN", "46204") }
  let(:office) { address(2, "CA", "90210") }
  let(:home_shipment) { shipment(11, home) }
  let(:office_shipment) { shipment(12, office) }

  let(:handler_calls) { [] }
  let(:logger) { instance_double(Logger, error: nil) }

  def address(id, state, zipcode)
    double("address #{id}", id: id, state: double(abbr: state), zipcode: zipcode)
  end

  def shipment(id, address)
    double("shipment #{id}", id: id, address: address, cost: 0, inventory_units: [double(quantity: 1)])
  end

  def breakdown(line_item_id, tax)
    double(
      "breakdown",
      line_items: [double(id: line_item_id.to_s, tax_collectable: BigDecimal(tax))],
      shipping?: false
    )
  end

  around do |example|
    original_handler = SuperGood::SolidusTaxjar.exception_handler
    original_logger = SuperGood::SolidusTaxjar.instance_variable_get(:@logger)
    example.run
  ensure
    SuperGood::SolidusTaxjar.exception_handler = original_handler
    SuperGood::SolidusTaxjar.logger = original_logger
  end

  before do
    SuperGood::SolidusTaxjar.logger = logger
    SuperGood::SolidusTaxjar.exception_handler = ->(error, context) { handler_calls << [error, context] }
  end

  context "when the second address group's call raises a TaxJar error" do
    let(:failure) { Taxjar::Error::InternalServerError.new("Internal Server Error") }

    before do
      allow(api).to receive(:tax_for).with(order, home, [home_shipment])
        .and_return(double(breakdown: breakdown(33, "7.00")))
      allow(api).to receive(:tax_for).with(order, office, [office_shipment]).and_raise(failure)
    end

    it "keeps the tax from the group that succeeded" do
      expect(order_tax.line_item_taxes.map(&:item_id)).to eq [33]
      expect(order_tax.line_item_taxes.map(&:amount)).to eq [BigDecimal("7.00")]
    end

    it "reports the failed group with the order and address context" do
      order_tax

      expect(handler_calls.size).to eq 1
      error, context = handler_calls.first
      expect(error).to be failure
      expect(context).to include(
        order_id: 10,
        order_number: "R100000001",
        scope: "address_group",
        address_id: 2,
        address_state: "CA",
        address_zipcode: "90210",
        shipment_ids: [12],
        error_class: "Taxjar::Error::InternalServerError",
        error_message: "Internal Server Error"
      )
    end

    it "logs an error that says the order keeps partial tax" do
      order_tax

      expect(logger).to have_received(:error)
        .with(a_string_including("this address group gets no tax", "R100000001", "\"address_id\":2"))
    end

    context "with a one-argument exception handler" do
      before do
        SuperGood::SolidusTaxjar.exception_handler = ->(error) { handler_calls << [error] }
      end

      it "still hands it the error" do
        order_tax

        expect(handler_calls).to eq [[failure]]
      end
    end
  end

  context "when a call times out" do
    before do
      allow(api).to receive(:tax_for).with(order, home, [home_shipment])
        .and_raise(Taxjar::Error.new(HTTP::TimeoutError.new("Read timed out after 8 seconds")))
      allow(api).to receive(:tax_for).with(order, office, [office_shipment])
        .and_return(double(breakdown: breakdown(34, "9.50")))
    end

    it "reports the timeout and keeps the other group's tax" do
      expect(order_tax.line_item_taxes.map(&:amount)).to eq [BigDecimal("9.50")]
      expect(handler_calls.map { |_, context| context[:address_id] }).to eq [1]
      expect(handler_calls.first.last[:error_message]).to match(/timed out/)
    end
  end

  context "when every address group's call fails" do
    before do
      allow(api).to receive(:tax_for).and_raise(Taxjar::Error::ServiceUnavailable.new("Service Unavailable"))
    end

    it "returns no tax and reports each group" do
      expect(order_tax.line_item_taxes).to be_empty
      expect(order_tax.shipment_taxes).to be_empty
      expect(handler_calls.map { |_, context| context[:address_id] }).to eq [1, 2]
    end
  end

  context "when something other than a TaxJar error fails" do
    before do
      allow(api).to receive(:tax_for).with(order, home, [home_shipment])
        .and_return(double(breakdown: breakdown(33, "7.00")))
      allow(api).to receive(:tax_for).with(order, office, [office_shipment])
        .and_raise(NoMethodError, "undefined method 'abbr' for nil")
    end

    it "drops the whole order's tax, as before, and reports it at order scope" do
      expect(order_tax.line_item_taxes).to be_empty
      expect(handler_calls.size).to eq 1
      expect(handler_calls.first.last).to include(scope: "order", order_number: "R100000001", error_class: "NoMethodError")
      expect(handler_calls.first.last).not_to have_key(:address_id)
    end
  end
end
