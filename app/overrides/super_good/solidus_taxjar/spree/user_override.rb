module SuperGood
  module SolidusTaxjar
    module Spree
      module UserOverride
        def self.prepended(base)
          base.has_one :taxjar_customer,
                       class_name: "SuperGood::SolidusTaxjar::Customer",
                       dependent: :destroy,
                       inverse_of: :user
        end

        ::Spree::User.prepend self
      end
    end
  end
end