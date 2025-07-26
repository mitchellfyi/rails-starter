# frozen_string_literal: true

# Synth Billing module installer for the Rails SaaS starter template.
# This module sets up Stripe integration with subscriptions, invoicing, and webhooks.

say_status :billing, "Installing billing module with Stripe integration"

# Add billing gems
add_gem 'stripe', '~> 13.0'
add_gem 'money-rails', '~> 1.15'
add_gem 'prawn', '~> 2.5' # For PDF generation
add_gem 'prawn-table', '~> 0.2'

after_bundle do
  # Configure Stripe
  initializer 'stripe.rb', <<~'RUBY'
    Rails.configuration.stripe = {
      publishable_key: Rails.application.credentials.stripe&.publishable_key,
      secret_key: Rails.application.credentials.stripe&.secret_key,
      webhook_secret: Rails.application.credentials.stripe&.webhook_secret
    }

    Stripe.api_key = Rails.configuration.stripe[:secret_key]
    Stripe.api_version = '2024-06-20'
  RUBY

  # Configure Money
  initializer 'money.rb', <<~'RUBY'
    MoneyRails.configure do |config|
      config.default_currency = :usd
      config.rounding_mode = BigDecimal::ROUND_HALF_UP
      config.default_format = {
        no_cents_if_whole: nil,
        symbol: nil,
        sign_before_symbol: nil
      }
    end
  RUBY

  # Generate billing models
  generate 'model', 'Plan', 'name:string', 'stripe_price_id:string', 'amount_cents:integer', 'currency:string', 'interval:string', 'trial_period_days:integer', 'features:text', 'active:boolean'
  
  generate 'model', 'Subscription', 'user:references', 'plan:references', 'stripe_subscription_id:string', 'status:string', 'current_period_start:datetime', 'current_period_end:datetime', 'trial_end:datetime', 'canceled_at:datetime'
  
  generate 'model', 'Invoice', 'user:references', 'subscription:references', 'stripe_invoice_id:string', 'amount_cents:integer', 'currency:string', 'status:string', 'invoice_date:date', 'due_date:date', 'paid_at:datetime'
  
  generate 'model', 'PaymentMethod', 'user:references', 'stripe_payment_method_id:string', 'type:string', 'last_four:string', 'brand:string', 'exp_month:integer', 'exp_year:integer', 'default:boolean'

  # Generate controllers
  generate 'controller', 'Billing', 'index'
  generate 'controller', 'Subscriptions', 'index', 'show', 'create', 'update', 'cancel'
  generate 'controller', 'Webhooks', 'stripe'

  # Create billing service
  create_file 'app/services/billing_service.rb', <<~'RUBY'
    class BillingService
      attr_reader :user

      def initialize(user)
        @user = user
      end

      def create_customer
        return user.stripe_customer_id if user.stripe_customer_id.present?

        customer = Stripe::Customer.create(
          email: user.email,
          name: user.full_name,
          metadata: { user_id: user.id }
        )

        user.update!(stripe_customer_id: customer.id)
        customer.id
      end

      def create_subscription(plan, payment_method_id = nil)
        customer_id = create_customer
        
        subscription_params = {
          customer: customer_id,
          items: [{ price: plan.stripe_price_id }],
          expand: ['latest_invoice.payment_intent']
        }

        if payment_method_id
          subscription_params[:default_payment_method] = payment_method_id
        end

        if plan.trial_period_days&.positive?
          subscription_params[:trial_period_days] = plan.trial_period_days
        end

        stripe_subscription = Stripe::Subscription.create(subscription_params)
        
        Subscription.create!(
          user: user,
          plan: plan,
          stripe_subscription_id: stripe_subscription.id,
          status: stripe_subscription.status,
          current_period_start: Time.at(stripe_subscription.current_period_start),
          current_period_end: Time.at(stripe_subscription.current_period_end),
          trial_end: stripe_subscription.trial_end ? Time.at(stripe_subscription.trial_end) : nil
        )
      end

      def cancel_subscription(subscription)
        Stripe::Subscription.update(
          subscription.stripe_subscription_id,
          cancel_at_period_end: true
        )

        subscription.update!(canceled_at: Time.current)
      end

      def update_payment_method(payment_method_id)
        customer_id = create_customer
        
        Stripe::PaymentMethod.attach(payment_method_id, { customer: customer_id })
        
        Stripe::Customer.update(customer_id, {
          invoice_settings: { default_payment_method: payment_method_id }
        })

        # Update or create payment method record
        stripe_pm = Stripe::PaymentMethod.retrieve(payment_method_id)
        
        PaymentMethod.create!(
          user: user,
          stripe_payment_method_id: payment_method_id,
          type: stripe_pm.type,
          last_four: stripe_pm.card&.last4,
          brand: stripe_pm.card&.brand,
          exp_month: stripe_pm.card&.exp_month,
          exp_year: stripe_pm.card&.exp_year,
          default: true
        )
      end

      def generate_invoice_pdf(invoice)
        InvoicePdfGenerator.new(invoice).generate
      end
    end
  RUBY

  # Create webhook handler
  create_file 'app/controllers/webhooks_controller.rb', <<~'RUBY'
    class WebhooksController < ApplicationController
      skip_before_action :verify_authenticity_token, only: [:stripe]
      before_action :verify_stripe_signature, only: [:stripe]

      def stripe
        case @event.type
        when 'invoice.payment_succeeded'
          handle_invoice_payment_succeeded(@event.data.object)
        when 'invoice.payment_failed'
          handle_invoice_payment_failed(@event.data.object)
        when 'customer.subscription.updated'
          handle_subscription_updated(@event.data.object)
        when 'customer.subscription.deleted'
          handle_subscription_deleted(@event.data.object)
        end

        head :ok
      end

      private

      def verify_stripe_signature
        payload = request.body.read
        sig_header = request.env['HTTP_STRIPE_SIGNATURE']
        endpoint_secret = Rails.configuration.stripe[:webhook_secret]

        begin
          @event = Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
        rescue JSON::ParserError, Stripe::SignatureVerificationError => e
          head :bad_request
          return
        end
      end

      def handle_invoice_payment_succeeded(invoice)
        subscription = Subscription.find_by(stripe_subscription_id: invoice.subscription)
        return unless subscription

        Invoice.find_or_create_by(stripe_invoice_id: invoice.id) do |inv|
          inv.user = subscription.user
          inv.subscription = subscription
          inv.amount_cents = invoice.amount_paid
          inv.currency = invoice.currency
          inv.status = 'paid'
          inv.invoice_date = Time.at(invoice.created)
          inv.paid_at = Time.current
        end
      end

      def handle_invoice_payment_failed(invoice)
        subscription = Subscription.find_by(stripe_subscription_id: invoice.subscription)
        return unless subscription

        # Handle failed payment - could send notification, update subscription status, etc.
        Rails.logger.warn "Payment failed for subscription #{subscription.id}"
      end

      def handle_subscription_updated(subscription)
        local_subscription = Subscription.find_by(stripe_subscription_id: subscription.id)
        return unless local_subscription

        local_subscription.update!(
          status: subscription.status,
          current_period_start: Time.at(subscription.current_period_start),
          current_period_end: Time.at(subscription.current_period_end)
        )
      end

      def handle_subscription_deleted(subscription)
        local_subscription = Subscription.find_by(stripe_subscription_id: subscription.id)
        return unless local_subscription

        local_subscription.update!(status: 'canceled', canceled_at: Time.current)
      end
    end
  RUBY

  # Create invoice PDF generator
  create_file 'app/services/invoice_pdf_generator.rb', <<~'RUBY'
    class InvoicePdfGenerator
      attr_reader :invoice

      def initialize(invoice)
        @invoice = invoice
      end

      def generate
        Prawn::Document.new do |pdf|
          # Header
          pdf.text "Invoice ##{invoice.id}", size: 24, style: :bold
          pdf.move_down 20

          # Invoice details
          pdf.text "Invoice Date: #{invoice.invoice_date.strftime('%B %d, %Y')}"
          pdf.text "Due Date: #{invoice.due_date&.strftime('%B %d, %Y')}"
          pdf.text "Status: #{invoice.status.humanize}"
          pdf.move_down 20

          # Customer info
          pdf.text "Bill To:", style: :bold
          pdf.text invoice.user.full_name
          pdf.text invoice.user.email
          pdf.move_down 20

          # Invoice items
          items = [
            ['Description', 'Amount'],
            [invoice.subscription.plan.name, format_currency(invoice.amount_cents, invoice.currency)]
          ]

          pdf.table(items, header: true, width: pdf.bounds.width) do
            row(0).font_style = :bold
            columns(1).align = :right
          end

          pdf.move_down 20
          pdf.text "Total: #{format_currency(invoice.amount_cents, invoice.currency)}", 
                   size: 16, style: :bold, align: :right
        end.render
      end

      private

      def format_currency(cents, currency)
        Money.new(cents, currency).format
      end
    end
  RUBY

  say_status :billing, "Billing module installed. Next steps:"
  say_status :billing, "1. Run rails db:migrate"
  say_status :billing, "2. Configure Stripe credentials"
  say_status :billing, "3. Add billing routes"
  say_status :billing, "4. Set up Stripe webhook endpoint"
  say_status :billing, "5. Create plan records with Stripe price IDs"
end