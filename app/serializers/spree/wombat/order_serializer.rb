require 'active_model/serializer'

module Spree
  module Wombat
    class OrderSerializer < ActiveModel::Serializer

      attributes :id, :status, :channel, :email, :currency, :totals,
        :adjustments, :tranDate, :customFormRef, :termsRef, :salesEffectiveDate,
        :customer_type, :stock_location

      has_many :line_items,  serializer: Spree::Wombat::LineItemSerializer
      has_many :payments, serializer: Spree::Wombat::PaymentSerializer
      has_many :promotions, serializer: Spree::Wombat::PromotionSerializer

      has_one :shipping_address, serializer: Spree::Wombat::AddressSerializer
      has_one :billing_address, serializer: Spree::Wombat::AddressSerializer

      def id
        object.number
      end

      #sales order transaction date as defined by netsuite
      def tranDate
        object.created_at.strftime("%m/%d/%Y")
      end

      #Does this order contain one or more PayPal payments
      #Required by Netsuite to determine sales order import flow
      def termsRef
        paypal_payments.present? ? '14' : '22'
      end

      def customFormRef
        "3DR Sales Order"
      end

      #Netsuite defines a sales effective date as the
      #date when payment was authorized
      def salesEffectiveDate
        if payment = object.payments.detect { |p| ['pending', 'completed'].include?(p.state) }
          payment.updated_at.strftime("%m/%d/%Y")
        else
          ""
        end
      end

      def completed_at
        object.completed_at
      end

      def customer_type
        return nil if object.user_type_id.nil?
        Spree::UserType.find_by_id(object.user_type_id).try(:name)
      end

      def stock_location
        object.try(:shipments).try(:first).try(:stock_location).try(:name) || "Unknown (is order complete?)" #orders will contain line items that belong to only one stock location after 3PL / Hayward goes live
      end

      def shipping_instructions
        object.special_instructions
      end

      def status
        object.state
      end

      def channel
        object.channel || 'spree'
      end

      def updated_at
        object.updated_at.getutc.try(:iso8601)
      end

      def placed_on
        if object.completed_at?
          object.completed_at.getutc.try(:iso8601)
        else
          ''
        end
      end

      def totals
        {
          item: object.item_total.to_f,
          adjustment: adjustment_total,
          tax: tax_total,
          shipping: shipping_total,
          payment: object.payments.completed.sum(:amount).to_f,
          order: object.total.to_f
        }
      end

      def adjustments
        [
          { name: 'discount', value: object.promo_total.to_f },
          { name: 'tax', value: tax_total },
          { name: 'shipping', value: shipping_total }
        ]
      end

      private

        def adjustment_total
          object.adjustment_total.to_f
        end

        def shipping_total
          object.shipment_total.to_f
        end

        def tax_total
          tax = 0.0
          tax_rate_taxes = (object.included_tax_total + object.additional_tax_total).to_f
          manual_import_adjustment_tax_adjustments = object.adjustments.select{|adjustment| adjustment.label.downcase == "tax" && adjustment.source_id == nil && adjustment.source_type == nil}
          if(tax_rate_taxes == 0.0 && manual_import_adjustment_tax_adjustments.present?)
            tax = manual_import_adjustment_tax_adjustments.sum(&:amount).to_f
          else
            tax = tax_rate_taxes
          end
          tax
        end

        def only_payment_is_paypal?
          if object.payments.length == 1
            payment = object.payments.first

            if payment.payment_method.type == "Spree::PaymentMethod::Check"
              true
            end
          end
        end

        def paypal_payments
          object.payments.find_all { |p| p.payment_method.type == "Spree::Gateway::PayPalExpress" }
        end

    end
  end
end
