require 'active_model/serializer'

module Spree
  module Wombat
    class SourceSerializer < ActiveModel::Serializer
      attributes :cc_type, :last_digits
      
      def cc_type
        object.try(:cc_type)
      end

      def last_digits
        object.try(:last_digits)
      end
    end
  end
end
