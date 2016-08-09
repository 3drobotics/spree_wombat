require 'active_model/serializer'

module Spree
  module Wombat
    class OrderSerializer < ActiveModel::Serializer

      attributes :id, :status, :channel, :email, :currency, :placed_on, :updated_at, :totals,
        :adjustments, :guest_token, :shipping_instructions, :tranDate, :customFormRef, :termsRef,
        :salesEffectiveDate, :authorization_code, :completed_at, :promotion_applied, :distro, :payment_gateway,
        :payment_method

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
        order.created_at.strftime("%m/%d/%Y")
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

      #To allow netsuite capture payment
      #Required by gateway
      def authorization_code
        auth_codes = []

        object.payments.each do |payment|
          if payment.payment_method.type == "Spree::Gateway::PayPalExpress"
            auth_codes << payment.source.transaction_id
          else
            auth_codes << payment.response_code
          end
        end

        auth_codes.join(" ")
      end

      def completed_at
        object.completed_at
      end

      def promotion_applied
        object.applied_coupon_code
      end

      #Is user a distributor
      def distro
        return '' if object.user.blank? ||
                     object.user.user_group.blank? ||
                     object.user.user_group.name.match(/^Distributor.*/).blank?
        '1'
      end

      def payment_gateway
        payment_method = object.payments.select { |p| p.payment_method.try(:type).present? }.first.try(:payment_method)
        return "" if payment_method.blank?

        if payment_method.type == "Spree::Gateway::CyberSource"
          if payment_method.preferences[:login] == "3drobotics1"
            return payment_method.type
          else
            return "#{payment_method.type}2"
          end
        else
          return payment_method.type
        end
      end

      def payment_method
        if payment_methods.count > 0
          payment_methods.join(" | ")
        else
          "Other"
        end
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

        def paypal_payments
          payments.find_all { |p| p.payment_method.type == "Spree::Gateway::PayPalExpress" }
        end

        def payment_methods
          if @payment_methods.nil?
            @payment_methods = []

            valid_payments = payments.find_all { |p| p.payment_method.respond_to?(:name) }
            valid_payments = valid_payments.reject { |p| ['failed', 'void', 'invalid', 'NULL'].include?(p.state) }

            valid_payments = [] if only_payment_is_paypal?

            valid_payments.each do |payment|
              if ["PayPal", "Paypal (manual)"].include?(payment.payment_method.name)
                @payment_methods << "PayPal"
              elsif ["Credit Card", "Credit Card - Old"].include?(payment.payment_method.name) && payment.respond_to?(:source)
                if payment.source.respond_to?(:cc_type)
                  @payment_methods << payment.source.cc_type
                else
                  @payment_methods << payment.source.source.cc_type
                end
              elsif payment.payment_method.name == "Wire transfer"
                @payment_methods << "Wire transfer"
              elsif payment.payment_method.type == "Spree::PaymentMethod::Check"
                @payment_methods << "Check"
              elsif payment.payment_method.name.present?
                @payment_methods << payment.payment_method.name
              end
            end

            @payment_methods.uniq!
          end

          @payment_methods
        end

    end
  end
end
