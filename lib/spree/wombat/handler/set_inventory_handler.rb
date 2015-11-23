module Spree
  module Wombat
    module Handler
      class SetInventoryHandler < Base

        def process
          sku = @payload[:inventory][:id]
          variant = Spree::Variant.find_by_sku(sku)
          return response("Product with SKU #{sku} was not found", 404) unless variant

          @payload[:inventory][:quantities].each do |inventory_payload|
            stock_location_name = inventory_payload.first
            stock_location = stock_location_mapper(stock_location_name)
            next unless stock_location == variant.preferred_stock_location

            inventory_at_location = inventory_payload.last

            return response("Stock location with name #{stock_location_name} was not found", 500) unless stock_location

            stock_item = stock_location.stock_items.where(variant: variant).first
            return response("Stock location '#{stock_location_name}' does not has any stock_items for #{sku}", 500) unless stock_item

            stock_item.set_count_on_hand(inventory_at_location)

            return response("Set inventory for #{sku} at #{stock_location_name} to #{stock_item.reload.count_on_hand}")

          end

        end

        def stock_location_mapper(netsuite_stock_location)
          {"3DR Global Warehouses : 3PL1 Warehouse (Ceva Hayward)" => Spree::StockLocation.hayward,
           "3DR Global Warehouses : 3PL2 Warehouse (PCH HK)"       => Spree::StockLocation.hk,
           "3DR Global Warehouses : 3DR San Diego Warehouse"       => Spree::StockLocation.san_diego
          }[netsuite_stock_location] || Spree::StockLocation.find_by_admin_name(netsuite_stock_location)
        end

      end
    end
  end
end
