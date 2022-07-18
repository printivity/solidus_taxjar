module Spree
  module Admin
    class TaxjarCustomersController < Spree::Admin::BaseController
      before_action :load_user
      before_action :load_taxjar_customer, except: %i[create]

      def new
        @taxjar_customer = @user.build_taxjar_customer
        @taxjar_customer.taxjar_exempt_regions.build
      end

      def show; end

      def edit; end

      def create
        @taxjar_customer = @user.build_taxjar_customer(object_params)

        if @taxjar_customer.save
          flash[:success] = "your user tax exemption has been saved"
          ::Spree::Event.fire "tax_exemption_created", user: @user
          redirect_to admin_user_tax_exemptions_path
        else
          flash[:error] = "your user tax exemption failed to save"
          redirect_back(fallback_location: new_admin_user_tax_exemptions_path)
        end
      end

      def destroy
        if @taxjar_customer.destroy
          flash[:success] = "Tax exemption has been deleted"
          ::Spree::Event.fire "tax_exemption_destroyed", user: @user
          redirect_to admin_user_tax_exemptions_path
        else
          flash[:error] = "Tax exemption could not be deleted"
          redirect_back(fallback_location: admin_user_tax_exemptions_path)
        end
        flash[:success] = "tax exemption has been deleted"
      end

      private

      def object_params
        params.require(:super_good_solidus_taxjar_customer).
          permit(:address_id, :tax_exemption_type,
                 taxjar_exempt_regions_attributes: [:state_id, :tax_exemption_document])
      end

      def load_taxjar_customer
        @taxjar_customer = @user.taxjar_customer
      end

      def load_user
        @user = ::Spree::User.find_by(id: params[:user_id])
      end

      def model_class
        SuperGood::SolidusTaxjar::Customer
      end
    end
  end
end
