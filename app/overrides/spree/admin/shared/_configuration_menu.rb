# frozen_string_literal: true

Deface::Override.new(
  virtual_path: 'spree/admin/shared/_taxes_tabs',
  name: 'add_taxjar_admin_menu_links',
  insert_bottom: "[data-hook='admin_settings_taxes_tabs']"
) do
  <<-HTML
    <%= configurations_sidebar_menu_item "TaxJar Settings", edit_admin_taxjar_settings_path %>

    <%= configurations_sidebar_menu_item "TaxJar Backfill", admin_transaction_sync_batches_path %>

    <%= configurations_sidebar_menu_item "Orders That Need Taxes Filed", need_taxes_filed_admin_orders_path %>
  HTML
end
