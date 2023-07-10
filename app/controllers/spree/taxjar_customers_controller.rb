module Spree
  class TaxjarCustomersController < ApiController
    before_action :load_taxjar_customer, except: %i[create]

    def show
      if @taxjar_customer
        render_ok_with_csrf("api/v1/taxjar_customers/show", taxjar_customer: @taxjar_customer)
      else
        render_ok_with_alerts_and_csrf
      end
    end

    def create
      @taxjar_customer = spree_current_user.build_taxjar_customer(object_params)

      if @taxjar_customer.save
        flash[:success] = "Tax exemption has been saved"
        Spree::Bus.publish :tax_exemption_created, user: spree_current_user
        Spree::Bus.publish :tax_exemption_customer_request, user: spree_current_user
        render_ok_with_csrf("api/v1/taxjar_customers/show", taxjar_customer: @taxjar_customer)
      else
        flash[:error] = "Tax exemption failed to save"
        render_bad_request_with_custom_message_and_errors("Tax exemption failed to save", @taxjar_customer.errors)
      end
    end

    def update
      @taxjar_customer = spree_current_user.taxjar_customer

      if @taxjar_customer.update(object_params)
        flash[:success] = "tax exemption has been updated"
        Spree::Bus.publish :tax_exemption_updated, user: spree_current_user
        Spree::Bus.publish :tax_exemption_customer_request, user: spree_current_user
        render_ok_with_csrf("api/v1/taxjar_customers/show", taxjar_customer: @taxjar_customer)
      else
        flash[:error] = "Tax exemption failed to update"
        render_bad_request_with_custom_message_and_errors("Tax exemption failed to update", @taxjar_customer.errors)
      end
    end

    def destroy
      if @taxjar_customer.destroy
        flash[:success] = "tax exemption has been deleted"
        Spree::Bus.publish :tax_exemption_destroyed, user: spree_current_user
        render_ok_with_csrf("api/v1/taxjar_customers/show", taxjar_customer: @taxjar_customer)
      else
        flash[:error] = "tax exemption could not be deleted"
        render_bad_request_with_custom_message_and_errors("Tax exemption failed to update", @ta.errors)
      end
    end

    def nexus_regions
      nexus_regions = SuperGood::SolidusTaxjar.api.nexus_regions

      render_ok_with_csrf("api/v1/taxjar_customers/nexus_regions", nexus_regions: nexus_regions)
    end

    private

    def object_params
      tax_params = params.require(:tax_exemption).
                   permit(:address_id, :tax_exemption_type, address_attributes: permitted_address_attributes,
               taxjar_exempt_regions_attributes: %i[id _destroy state_id tax_exemption_document])

      if tax_params[:address_id].to_i.positive?
        tax_params.delete(:address_attributes)
      else
        tax_params.delete(:ship_address_id)
      end

      tax_params
    end

    def load_taxjar_customer
      @taxjar_customer = spree_current_user.taxjar_customer
    end
  end
end
