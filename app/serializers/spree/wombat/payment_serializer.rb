require 'active_model/serializer'

module Spree
  module Wombat
    class PaymentSerializer < ActiveModel::Serializer
      attributes :id, :number, :status, :amount, :payment_method, :payment_gateway, :authorization_code, :transaction_id

      has_one :source, serializer: Spree::Wombat::SourceSerializer

      def payment_method
        object.payment_method.name
      end

      def status
        object.state
      end

      def amount
        object.amount.to_f
      end

      def authorization_code
        object.payment_method.type == "Spree::Gateway::PayPalExpress" ? object.source.transaction_id : object.response_code
      end

      def transaction_id
        transaction_id = object.order.number

        paypal_payments.each do |payment|
          if payment.source.respond_to?(:transaction_id)
            transaction_id = payment.source.token
          end
        end

        transaction_id
      end

      def paypal_payments
        object.order.payments.find_all { |p| p.payment_method.type == "Spree::Gateway::PayPalExpress" }
      end

      def payment_gateway
        object.payment_method.type
      end

    end
  end
end
