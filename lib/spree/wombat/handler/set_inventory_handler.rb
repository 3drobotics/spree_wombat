module Spree
  module Wombat
    module Handler
      class SetInventoryHandler < Base

        def process
          sku = @payload[:inventory][:sku]
          variant = Spree::Variant.find_by_sku(sku)
          return response("Product with SKU #{sku} was not found", 404) unless variant

          @payload[:inventory][:locations].each do |inventory_payload|
            stock_location_name   = inventory_payload.first
            inventory_at_location = inventory_payload.last

            stock_location = Spree::StockLocation.find_by_name(stock_location_name) || Spree::StockLocation.find_by_admin_name(stock_location_name)
            return response("Stock location with name #{stock_location_name} was not found", 500) unless stock_location

            stock_item = stock_location.stock_items.where(variant: variant).first
            return response("Stock location '#{stock_location_name}' does not has any stock_items for #{sku}", 500) unless stock_item

            count_on_hand = stock_item.count_on_hand
            stock_item.set_count_on_hand(inventory_at_location)

            return response("Set inventory for #{sku} at #{stock_location_name} from #{count_on_hand} to #{stock_item.reload.count_on_hand}")

          end

        end

      end
    end
  end
end
