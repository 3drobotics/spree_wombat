module Spree
  StockLocation.class_eval do
    class << self
      def hayward
        @@hayward   ||= find_by(name: '3DR Global Warehouses - Hayward')
      end
      def hk
        @@hk        ||= find_by(name: '3DR Global Warehouses - HK')
      end
      def san_diego
        @@san_diego ||= find_by(name: '3DR Global Warehouses - San Diego')
      end
    end
  end
end
