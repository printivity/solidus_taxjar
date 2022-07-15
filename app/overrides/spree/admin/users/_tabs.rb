# frozen_string_literal: true

Deface::Override.new(
  virtual_path: 'spree/admin/users/_tabs',
  name: 'add_user_tax_exemptions_admin_menu_links',
  insert_bottom: "[data-hook='admin_user_tab_options']"
) do
  <<-HTML
    <% if can?(:manage, SuperGood::SolidusTaxjar::Customer) %>
      <li<%== ' class="active"' if current == :tax_exemptions %>>
        <%= link_to 'tax exemptions', "/admin/users/#{@user.id}/tax_exemptions" %>
      </li>
    <% end %>
  HTML
end
