require "spec_helper"

RSpec.describe ::SuperGood::SolidusTaxjar::TaxRateCalculator do
  describe "#calculate" do
    subject { calculator.calculate }

    let(:calculator) { described_class.new(address, api: dummy_api) }

    let(:dummy_api) do
      instance_double ::SuperGood::SolidusTaxjar::Api
    end

    let(:dummy_tax_rate) { BigDecimal(0) }

    let(:empty_address) do
      ::Spree::Address.new
    end

    let(:incomplete_address) do
      ::Spree::Address.new(
        first_name: "Ronnie James",
        zipcode: nil,
        address1: nil,
        city: "Beverly Hills",
        state_name: "California",
        country: ::Spree::Country.new(iso: "US")
      )
    end

    let(:complete_address) do
      incomplete_address.tap do |address|
        address.zipcode = "90210"
        address.address1 = "9900 Wilshire Blvd"
      end
    end

    shared_examples "returns the dummy tax rate" do
      it { expect(subject).to eq dummy_tax_rate }
    end

    context "when the address is an empty address" do
      let(:address) { empty_address }

      context "when we're not rescuing from errors" do
        around do |example|
          handler = SuperGood::SolidusTaxjar.exception_handler
          SuperGood::SolidusTaxjar.exception_handler = ->(error) { raise error }
          example.run
          SuperGood::SolidusTaxjar.exception_handler = handler
        end

        it_behaves_like "returns the dummy tax rate"
      end
    end

    context "when the address is not complete" do
      let(:address) { incomplete_address }

      it_behaves_like "returns the dummy tax rate"
    end

    context "when the address is complete" do
      let(:address) { complete_address }

      context "when the address is not taxable" do
        before do
          allow(SuperGood::SolidusTaxjar.taxable_address_check)
            .to receive(:call).with(address)
            .and_return(false)
        end

        it_behaves_like "returns the dummy tax rate"
      end

      context "when the address is taxable" do
        let(:tax_rate) { 0.03 }

        before do
          allow(dummy_api).to receive(:tax_rate_for) { tax_rate }
        end

        it "returns the expected tax rate" do
          expect(subject).to eq tax_rate
        end
      end
    end

    context "when the API encounters an error and default rates are present" do
      let(:address) { complete_address }

      let(:state_california) do
        Spree::State.create!(
          abbr: "CA",
          country: country_us,
          name: "California"
        )
      end

      let(:spree_zone) do
        Spree::Zone.create!(
          name: "CA zone",
          description: "CA zone for taxes"
        )
      end

      let(:spree_zone_member) do
        Spree::ZoneMember.create!(
          zonable: state_california,
          zone: spree_zone
        )
      end

      let(:spree_tax_rate) do
        Spree::Zone.create!(
          amount: BigDecimal(0.08),
          zone: spree_zone,
          name: "CA tax rate"
        )
      end

      before do
        allow(dummy_api).to receive(:tax_rate_for).and_raise("A bad thing happened.")
      end

      it "calls the configured error handler" do
        expect(SuperGood::SolidusTaxjar.exception_handler).to receive(:call) do |e|
          expect(e).to be_a StandardError
          expect(e.message).to eq "A bad thing happened."
        end

        subject
      end

      it "returns the default rate" do
        expect(subject).to eq spree_tax_rate.amount
      end
    end

    context "when the API encounters an error and default rates are not present" do
      let(:address) { complete_address }

      before do
        allow(dummy_api).to receive(:tax_rate_for).and_raise("A bad thing happened.")
      end

      it "calls the configured error handler" do
        expect(SuperGood::SolidusTaxjar.exception_handler).to receive(:call) do |e|
          expect(e).to be_a StandardError
          expect(e.message).to eq "A bad thing happened."
        end

        subject
      end

      it_behaves_like "returns the dummy tax rate"
    end

    context "when test_mode is set" do
      let(:address) { complete_address }

      before { SuperGood::SolidusTaxjar.test_mode = true }
      after { SuperGood::SolidusTaxjar.test_mode = false }

      it_behaves_like "returns the dummy tax rate"
    end
  end
end
