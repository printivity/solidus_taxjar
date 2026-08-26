require "spec_helper"

RSpec.describe "Admin TaxJar exempt regions", type: :request do
  extend Spree::TestingSupport::AuthorizationHelpers::Request
  stub_authorization!

  around do |example|
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
    example.run
    ActionController::Base.allow_forgery_protection = original
  end

  describe "POST #create" do
    let(:user) { create(:user) }

    let!(:taxjar_customer) do
      SuperGood::SolidusTaxjar::Customer.create!(
        user: user,
        address: create(:address),
        tax_exemption_type: "wholesale"
      )
    end

    context "when the exempt region cannot be saved" do
      it "redirects back to the new exempt region form instead of raising" do
        post spree.admin_user_tax_exemptions_exempt_regions_path(user),
             params: { exempt_region: { state_id: "" } }

        expect(response).to redirect_to(
          spree.new_admin_user_tax_exemptions_exempt_region_path(user)
        )
        expect(flash[:error]).to eq("State exemption failed to save")
      end
    end
  end
end
