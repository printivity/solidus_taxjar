require "spec_helper"

RSpec.describe SuperGood::SolidusTaxjar::Spree::TaxExemptionsSubscriber do
  subject(:subscriber) { described_class.new }

  let(:mailer_class) { SuperGood::SolidusTaxjar::TaxExemptionMailer }
  let(:delivery) { instance_double(ActionMailer::MessageDelivery, deliver_now: true) }
  let(:user) { instance_double(Spree::User) }
  let(:state) { instance_double(Spree::State) }

  def build_event(state: nil)
    instance_double(Omnes::UnstructuredEvent, payload: {user: user, state: state})
  end

  before do
    allow(mailer_class).to receive(:tax_exemption_request).and_return(delivery)
    allow(mailer_class).to receive(:approved_email).and_return(delivery)
    allow(mailer_class).to receive(:disapproved_email).and_return(delivery)
  end

  after do
    SuperGood::SolidusTaxjar.customer_email_enabled = ->(_user) { true }
  end

  it "sends approval email by default" do
    subscriber.send_approved_email(build_event(state: state))

    expect(mailer_class).to have_received(:approved_email).with(user, state)
    expect(delivery).to have_received(:deliver_now)
  end

  it "does not send approval email when the host policy rejects the user" do
    SuperGood::SolidusTaxjar.customer_email_enabled = ->(_user) { false }

    subscriber.send_approved_email(build_event(state: state))

    expect(mailer_class).not_to have_received(:approved_email)
  end

  it "does not send disapproval email when the host policy rejects the user" do
    SuperGood::SolidusTaxjar.customer_email_enabled = ->(_user) { false }

    subscriber.send_disapproved_email(build_event(state: state))

    expect(mailer_class).not_to have_received(:disapproved_email)
  end

  it "does not apply the customer policy to the internal request notification" do
    SuperGood::SolidusTaxjar.customer_email_enabled = ->(_user) { false }

    subscriber.send_notification_email(build_event)

    expect(mailer_class).to have_received(:tax_exemption_request).with(user)
    expect(delivery).to have_received(:deliver_now)
  end

  describe "#delete_customer" do
    let(:api) { instance_double(SuperGood::SolidusTaxjar::Api) }

    before do
      allow(SuperGood::SolidusTaxjar).to receive(:api).and_return(api)
    end

    it "deletes the TaxJar customer when one exists" do
      allow(api).to receive(:show_customer_for).with(user).and_return(instance_double(Taxjar::Customer))
      allow(api).to receive(:delete_customer_for).with(user)

      subscriber.delete_customer(build_event)

      expect(api).to have_received(:delete_customer_for).with(user)
    end

    it "does not call delete when TaxJar has no customer for the user" do
      allow(api).to receive(:show_customer_for).with(user).and_return(nil)
      allow(api).to receive(:delete_customer_for)

      subscriber.delete_customer(build_event)

      expect(api).not_to have_received(:delete_customer_for)
    end
  end
end
