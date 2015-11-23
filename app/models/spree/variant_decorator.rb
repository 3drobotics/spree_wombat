module Spree
  Variant.class_eval do
    preference :stock_location_id, :integer

    def preferred_stock_location
      if location_id = preferred_stock_location_id
        StockLocation.find(location_id)
      elsif solo?
        StockLocation.hayward
      else
        StockLocation.san_diego
      end
    end

  end
end
