# frozen_string_literal: true

require 'digest'

module Stubs
  # Stub client for Stripe API calls in test environment
  # Returns deterministic, predictable responses for testing
  class StripeClientStub
    def initialize(api_key: nil)
      @api_key = api_key
    end

    # Customer operations
    module Customer
      def self.create(params = {})
        email = params[:email] || 'test@example.com'
        name = params[:name] || 'Test Customer'
        
        customer_id = generate_id('cus', email)
        
        {
          'id' => customer_id,
          'object' => 'customer',
          'created' => Time.now.to_i,
          'email' => email,
          'name' => name,
          'description' => params[:description],
          'phone' => params[:phone],
          'address' => params[:address],
          'shipping' => params[:shipping],
          'tax_exempt' => 'none',
          'currency' => 'usd',
          'default_source' => nil,
          'invoice_prefix' => customer_id.upcase,
          'livemode' => false,
          'metadata' => params[:metadata] || {},
          'sources' => {
            'object' => 'list',
            'data' => [],
            'has_more' => false,
            'total_count' => 0,
            'url' => "/v1/customers/#{customer_id}/sources"
          },
          'subscriptions' => {
            'object' => 'list',
            'data' => [],
            'has_more' => false,
            'total_count' => 0,
            'url' => "/v1/customers/#{customer_id}/subscriptions"
          }
        }
      end

      def self.retrieve(customer_id)
        # Return existing customer or generate one
        {
          'id' => customer_id,
          'object' => 'customer',
          'created' => (Time.now - 30.days).to_i,
          'email' => 'existing@example.com',
          'name' => 'Existing Customer',
          'description' => nil,
          'currency' => 'usd',
          'default_source' => nil,
          'livemode' => false,
          'metadata' => {}
        }
      end

      def self.update(customer_id, params = {})
        customer = retrieve(customer_id)
        customer.merge!(params.stringify_keys)
        customer
      end

      def self.delete(customer_id)
        {
          'id' => customer_id,
          'object' => 'customer',
          'deleted' => true
        }
      end

      def self.list(params = {})
        limit = params[:limit] || 10
        
        customers = (1..limit).map do |i|
          {
            'id' => generate_id('cus', "customer#{i}"),
            'object' => 'customer',
            'created' => (Time.now - i.days).to_i,
            'email' => "customer#{i}@example.com",
            'name' => "Test Customer #{i}",
            'currency' => 'usd',
            'livemode' => false,
            'metadata' => {}
          }
        end

        {
          'object' => 'list',
          'data' => customers,
          'has_more' => false,
          'url' => '/v1/customers'
        }
      end

      private

      def self.generate_id(prefix, seed)
        hash = Digest::MD5.hexdigest(seed.to_s)[0..14]
        "#{prefix}_#{hash}"
      end
    end

    # Subscription operations
    module Subscription
      def self.create(params = {})
        customer_id = params[:customer] || 'cus_test123'
        price_id = params[:items]&.first&.dig(:price) || 'price_test123'
        
        subscription_id = generate_id('sub', "#{customer_id}-#{price_id}")
        
        {
          'id' => subscription_id,
          'object' => 'subscription',
          'created' => Time.now.to_i,
          'customer' => customer_id,
          'status' => params[:trial_period_days] ? 'trialing' : 'active',
          'start_date' => Time.now.to_i,
          'current_period_start' => Time.now.to_i,
          'current_period_end' => (Time.now + 1.month).to_i,
          'trial_start' => params[:trial_period_days] ? Time.now.to_i : nil,
          'trial_end' => params[:trial_period_days] ? (Time.now + params[:trial_period_days].days).to_i : nil,
          'currency' => 'usd',
          'items' => {
            'object' => 'list',
            'data' => [
              {
                'id' => generate_id('si', subscription_id),
                'object' => 'subscription_item',
                'created' => Time.now.to_i,
                'price' => {
                  'id' => price_id,
                  'object' => 'price',
                  'currency' => 'usd',
                  'unit_amount' => 2000, # $20.00
                  'recurring' => {
                    'interval' => 'month',
                    'interval_count' => 1
                  }
                },
                'quantity' => 1,
                'subscription' => subscription_id
              }
            ],
            'has_more' => false,
            'total_count' => 1
          },
          'latest_invoice' => generate_id('in', subscription_id),
          'metadata' => params[:metadata] || {},
          'cancel_at_period_end' => false,
          'canceled_at' => nil,
          'ended_at' => nil
        }
      end

      def self.retrieve(subscription_id)
        {
          'id' => subscription_id,
          'object' => 'subscription',
          'created' => (Time.now - 1.month).to_i,
          'customer' => 'cus_existing123',
          'status' => 'active',
          'current_period_start' => Time.now.to_i,
          'current_period_end' => (Time.now + 1.month).to_i,
          'currency' => 'usd',
          'metadata' => {}
        }
      end

      def self.update(subscription_id, params = {})
        subscription = retrieve(subscription_id)
        subscription.merge!(params.stringify_keys)
        subscription
      end

      def self.cancel(subscription_id, params = {})
        {
          'id' => subscription_id,
          'object' => 'subscription',
          'status' => 'canceled',
          'canceled_at' => Time.now.to_i,
          'ended_at' => Time.now.to_i,
          'cancel_at_period_end' => false
        }
      end

      private

      def self.generate_id(prefix, seed)
        hash = Digest::MD5.hexdigest(seed.to_s)[0..14]
        "#{prefix}_#{hash}"
      end
    end

    # Payment Method operations
    module PaymentMethod
      def self.create(params = {})
        payment_method_id = generate_id('pm', params[:type] || 'card')
        
        {
          'id' => payment_method_id,
          'object' => 'payment_method',
          'created' => Time.now.to_i,
          'customer' => params[:customer],
          'type' => params[:type] || 'card',
          'card' => {
            'brand' => 'visa',
            'checks' => {
              'address_line1_check' => 'pass',
              'address_postal_code_check' => 'pass',
              'cvc_check' => 'pass'
            },
            'country' => 'US',
            'exp_month' => 12,
            'exp_year' => 2025,
            'fingerprint' => 'abcd1234',
            'funding' => 'credit',
            'last4' => '4242',
            'networks' => {
              'available' => ['visa'],
              'preferred' => nil
            },
            'three_d_secure_usage' => {
              'supported' => true
            },
            'wallet' => nil
          },
          'metadata' => params[:metadata] || {}
        }
      end

      def self.retrieve(payment_method_id)
        {
          'id' => payment_method_id,
          'object' => 'payment_method',
          'created' => (Time.now - 1.day).to_i,
          'type' => 'card',
          'card' => {
            'brand' => 'visa',
            'last4' => '4242',
            'exp_month' => 12,
            'exp_year' => 2025
          }
        }
      end

      private

      def self.generate_id(prefix, seed)
        hash = Digest::MD5.hexdigest(seed.to_s)[0..14]
        "#{prefix}_#{hash}"
      end
    end

    # Invoice operations
    module Invoice
      def self.create(params = {})
        customer_id = params[:customer] || 'cus_test123'
        invoice_id = generate_id('in', customer_id)
        
        {
          'id' => invoice_id,
          'object' => 'invoice',
          'created' => Time.now.to_i,
          'customer' => customer_id,
          'status' => 'draft',
          'amount_due' => 2000,
          'amount_paid' => 0,
          'amount_remaining' => 2000,
          'currency' => 'usd',
          'due_date' => (Time.now + 30.days).to_i,
          'lines' => {
            'object' => 'list',
            'data' => [
              {
                'id' => generate_id('il', invoice_id),
                'object' => 'line_item',
                'amount' => 2000,
                'currency' => 'usd',
                'description' => 'Subscription',
                'quantity' => 1
              }
            ],
            'has_more' => false,
            'total_count' => 1
          },
          'metadata' => params[:metadata] || {}
        }
      end

      def self.retrieve(invoice_id)
        {
          'id' => invoice_id,
          'object' => 'invoice',
          'created' => (Time.now - 1.week).to_i,
          'status' => 'paid',
          'amount_due' => 2000,
          'amount_paid' => 2000,
          'amount_remaining' => 0,
          'currency' => 'usd'
        }
      end

      private

      def self.generate_id(prefix, seed)
        hash = Digest::MD5.hexdigest(seed.to_s)[0..14]
        "#{prefix}_#{hash}"
      end
    end

    # Expose modules as class methods
    def self.const_missing(name)
      case name
      when :Customer
        Customer
      when :Subscription
        Subscription
      when :PaymentMethod
        PaymentMethod
      when :Invoice
        Invoice
      else
        super
      end
    end

    # Instance methods that delegate to class methods
    def customer
      self.class::Customer
    end

    def subscription
      self.class::Subscription
    end

    def payment_method
      self.class::PaymentMethod
    end

    def invoice
      self.class::Invoice
    end

    # Error simulation for testing error handling
    def simulate_error(error_type = :card_declined)
      case error_type
      when :card_declined
        raise StandardError, "Your card was declined"
      when :insufficient_funds
        raise StandardError, "Your card has insufficient funds"
      when :invalid_request
        raise StandardError, "Invalid request parameters"
      when :api_error
        raise StandardError, "Stripe API temporarily unavailable"
      else
        raise StandardError, "Unknown Stripe error"
      end
    end

    private

    def self.generate_id(prefix, seed)
      hash = Digest::MD5.hexdigest(seed.to_s)[0..14]
      "#{prefix}_#{hash}"
    end
  end
end