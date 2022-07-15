module Spree
  module Admin
    class TaxjarExemptRegionsController < Spree::Admin::BaseController
      before_action :load_user
      before_action :load_taxjar_customer

      def new
        @taxjar_exempt_region = @taxjar_customer.taxjar_exempt_regions.build
      end

      def create
        @taxjar_exempt_region = @taxjar_customer.taxjar_exempt_regions.new(object_params)

        if @taxjar_exempt_region.save
          flash[:success] = "State exemption has been saved"
          Spree::Event.fire "tax_exemption_updated", user: @user
          redirect_to admin_user_tax_exemptions_path
        else
          flash[:error] = "State exemption failed to save"
          redirect_back(fallback_location: new_admin_user_tax_exemptions_exemption_region_path)
        end
      end

      def destroy
        exempt_region = @taxjar_customer.taxjar_exempt_regions.find(params[:id])

        if exempt_region.destroy
          flash[:success] = "State exemption has been deleted"
          if @taxjar_customer.taxjar_exempt_regions.blank?
            @taxjar_customer.destroy
            Spree::Event.fire "tax_exemption_destroyed", user: @user
          else
            Spree::Event.fire "tax_exemption_updated", user: @user
          end
        else
          flash[:error] = "State exemption could not be deleted"
        end
        redirect_to admin_user_tax_exemptions_path
      end

      def approve
        exempt_region = @taxjar_customer.taxjar_exempt_regions.find(params[:id])
        if exempt_region.update(approved: true)
          flash[:success] = "State exemption approved"
          Spree::Event.fire "tax_exemption_updated", user: @user
          Spree::Event.fire "tax_exemption_approved", user: @user, state: exempt_region.state
        else
          flash[:error] = "State exemption could not be approved"
        end
        redirect_to admin_user_tax_exemptions_path
      end

      def disapprove
        exempt_region = @taxjar_customer.taxjar_exempt_regions.find(params[:id])
        if exempt_region.update(approved: false)
          flash[:success] = "State exemption disapproved"
          Spree::Event.fire "tax_exemption_updated", user: @user
          Spree::Event.fire "tax_exemption_disapproved", user: @user, state: exempt_region.state
        else
          flash[:error] = "State exemption could not be disapproved"
        end
        redirect_to admin_user_tax_exemptions_path
      end

      private

      def object_params
        params.require(:exempt_region).
          permit(:state_id, :tax_exemption_document)
      end

      def load_taxjar_customer
        @taxjar_customer = @user.taxjar_customer
      end

      def load_user
        @user = Spree::User.find_by(id: params[:user_id])
      end

      def model_class
        SuperGood::SolidusTaxjar::ExemptRegion
      end
    end
  end
end
