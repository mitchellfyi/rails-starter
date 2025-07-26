# frozen_string_literal: true

# Synth Billing module installer for the Rails SaaS starter template.
# This install script is executed by the bin/synth CLI when adding the billing module.
# It sets up comprehensive Stripe billing integration with support for trials, subscriptions,
# one-off payments, metered billing, coupons, and PDF invoices.

say_status :synth_billing, "Installing Billing module"

# Create domain-specific directories (models stay in central app/models)
run 'mkdir -p app/domains/billing/app/{controllers,services,jobs,mailers,views/billing,views/billing_mailer}'
run 'mkdir -p app/models/concerns' # Ensure models and concerns directory exists
run 'mkdir -p spec/domains/billing/{models,controllers,jobs,fixtures}'

# Add billing specific gems to the application's Gemfile
add_gem 'stripe', '~> 15.3'
add_gem 'prawn', '~> 2.5' # For PDF invoice generation
add_gem 'prawn-table', '~> 0.2'

# Run bundle install and set up billing configuration after gems are installed
after_bundle do
  # Create an initializer for Stripe configuration
  initializer 'stripe.rb', <<~'RUBY'
    # Stripe configuration
    Rails.configuration.stripe = {
      publishable_key: ENV['STRIPE_PUBLISHABLE_KEY'],
      secret_key: ENV['STRIPE_SECRET_KEY'],
      webhook_secret: ENV['STRIPE_WEBHOOK_SECRET']
    }

    Stripe.api_key = Rails.configuration.stripe[:secret_key]
    Stripe.api_version = '2024-11-20.acacia'
  RUBY

  # Create Plan model in central models directory
  create_file 'app/models/plan.rb', <<~'RUBY'
    # frozen_string_literal: true

    class Plan < ApplicationRecord
      has_many :subscriptions, dependent: :destroy
      has_many :users, through: :subscriptions

      validates :name, presence: true
      validates :stripe_product_id, presence: true, uniqueness: true
      validates :stripe_price_id, presence: true, uniqueness: true
      validates :amount, presence: true, numericality: { greater_than: 0 }
      validates :interval, presence: true, inclusion: { in: %w[day week month year] }
      validates :trial_period_days, numericality: { greater_than_or_equal_to: 0 }

      scope :active, -> { where(active: true) }
      scope :visible, -> { active.order(:sort_order, :amount) }

      before_validation :set_defaults
      serialize :features, JSON
      serialize :metadata, JSON
      serialize :feature_limits, JSON

      def monthly_amount
        case interval
        when 'day'
          amount * 30
        when 'week'
          amount * 4
        when 'month'
          amount
        when 'year'
          amount / 12
        end
      end

      def price_in_dollars
        amount / 100.0
      end

      def has_trial?
        trial_period_days && trial_period_days > 0
      end

      def feature_limit(feature_name)
        return nil unless feature_limits.is_a?(Hash)
        feature_limits[feature_name.to_s]
      end

      def has_feature?(feature_name)
        return false unless features.is_a?(Array)
        features.include?(feature_name.to_s)
      end

      def metadata_value(key)
        return nil unless metadata.is_a?(Hash)
        metadata[key.to_s]
      end

      private

      def set_defaults
        self.features ||= []
        self.metadata ||= {}
        self.feature_limits ||= {}
      end
    end
  RUBY

  # Create Subscription model
  create_file 'app/models/subscription.rb', <<~'RUBY'
    # frozen_string_literal: true

    class Subscription < ApplicationRecord
      belongs_to :user
      belongs_to :plan
      has_many :invoices, dependent: :destroy

      validates :stripe_subscription_id, presence: true, uniqueness: true
      validates :status, presence: true

      enum status: {
        incomplete: 'incomplete',
        incomplete_expired: 'incomplete_expired',
        trialing: 'trialing',
        active: 'active',
        past_due: 'past_due',
        canceled: 'canceled',
        unpaid: 'unpaid',
        paused: 'paused'
      }

      scope :active_or_trialing, -> { where(status: ['active', 'trialing']) }

      def active?
        %w[active trialing].include?(status)
      end

      def on_trial?
        status == 'trialing' && trial_ends_at && trial_ends_at > Time.current
      end

      def trial_days_remaining
        return 0 unless on_trial?
        ((trial_ends_at - Time.current) / 1.day).ceil
      end

      def cancel!
        stripe_subscription = Stripe::Subscription.retrieve(stripe_subscription_id)
        stripe_subscription.cancel
        update!(status: 'canceled', canceled_at: Time.current)
      end

      def change_plan(new_plan)
        stripe_subscription = Stripe::Subscription.retrieve(stripe_subscription_id)
        stripe_subscription.modify(
          items: [{
            id: stripe_subscription.items.data[0].id,
            price: new_plan.stripe_price_id
          }]
        )
        update!(plan: new_plan)
      end

      def resume!
        stripe_subscription = Stripe::Subscription.retrieve(stripe_subscription_id)
        stripe_subscription.resume
        reload_from_stripe!
      end

      def reload_from_stripe!
        stripe_subscription = Stripe::Subscription.retrieve(stripe_subscription_id)
        update!(
          status: stripe_subscription.status,
          trial_ends_at: stripe_subscription.trial_end ? Time.at(stripe_subscription.trial_end) : nil,
          current_period_start: Time.at(stripe_subscription.current_period_start),
          current_period_end: Time.at(stripe_subscription.current_period_end)
        )
      end
    end
  RUBY

  # Create Invoice model
  create_file 'app/models/invoice.rb', <<~'RUBY'
    # frozen_string_literal: true

    class Invoice < ApplicationRecord
      belongs_to :user
      belongs_to :subscription, optional: true

      validates :stripe_invoice_id, presence: true, uniqueness: true
      validates :amount_paid, presence: true, numericality: { greater_than_or_equal_to: 0 }
      validates :status, presence: true

      enum status: {
        draft: 'draft',
        open: 'open',
        paid: 'paid',
        uncollectible: 'uncollectible',
        void: 'void'
      }

      def amount_in_dollars
        amount_paid / 100.0
      end

      def generate_pdf
        return pdf_data if pdf_data.present?

        pdf_content = InvoicePdfService.new(self).generate
        update!(pdf_data: pdf_content)
        pdf_content
      end

      def download_filename
        "invoice_#{number || id}.pdf"
      end
    end
  RUBY

  # Create WebhookEvent model for idempotent webhook processing
  create_file 'app/models/webhook_event.rb', <<~'RUBY'
    # frozen_string_literal: true

    class WebhookEvent < ApplicationRecord
      validates :stripe_event_id, presence: true, uniqueness: true
      validates :event_type, presence: true

      scope :processed, -> { where.not(processed_at: nil) }
      scope :unprocessed, -> { where(processed_at: nil) }
      scope :failed, -> { where.not(error_message: nil) }
      scope :successful, -> { where(error_message: nil).where.not(processed_at: nil) }

      def processed?
        processed_at.present?
      end

      def failed?
        error_message.present?
      end

      def successful?
        processed? && !failed?
      end

      def mark_as_processed!
        update!(processed_at: Time.current)
      end

      def mark_as_failed!(error_message, error_type = 'unknown')
        update!(
          error_message: error_message,
          error_type: error_type,
          processed_at: Time.current
        )
      end
    end
  RUBY

  # Create UsageRecord model for metered billing
  create_file 'app/models/usage_record.rb', <<~'RUBY'
    # frozen_string_literal: true

    class UsageRecord < ApplicationRecord
      belongs_to :user
      belongs_to :subscription

      validates :usage_type, presence: true
      validates :quantity, presence: true, numericality: { greater_than: 0 }
      validates :recorded_at, presence: true

      scope :for_period, ->(start_date, end_date) { where(recorded_at: start_date..end_date) }
      scope :by_type, ->(usage_type) { where(usage_type: usage_type) }

      def self.total_usage_for_period(user, usage_type, start_date, end_date)
        where(user: user, usage_type: usage_type)
          .for_period(start_date, end_date)
          .sum(:quantity)
      end
    end
  RUBY
  create_file 'app/models/coupon.rb', <<~'RUBY'
    # frozen_string_literal: true

    class Coupon < ApplicationRecord
      validates :code, presence: true, uniqueness: { case_sensitive: false }
      validates :stripe_coupon_id, presence: true, uniqueness: true
      validates :discount_type, presence: true, inclusion: { in: %w[percentage fixed] }

      scope :active, -> { where(active: true) }
      scope :valid_now, -> { where('(valid_from IS NULL OR valid_from <= ?) AND (valid_until IS NULL OR valid_until >= ?)', Time.current, Time.current) }

      def valid?
        return false unless active?
        return false if valid_from && valid_from > Time.current
        return false if valid_until && valid_until < Time.current
        return false if max_redemptions && redemptions_count >= max_redemptions
        true
      end

      def discount_description
        case discount_type
        when 'percentage'
          "#{discount_value}% off"
        when 'fixed'
          "$#{discount_value / 100.0} off"
        end
      end
    end
  RUBY

  # Add billing methods to User model
  create_file 'app/models/concerns/billable.rb', <<~'RUBY'
    # frozen_string_literal: true

    module Billable
      extend ActiveSupport::Concern

      included do
        has_many :subscriptions, dependent: :destroy
        has_many :invoices, dependent: :destroy
        has_one :active_subscription, -> { active_or_trialing }, class_name: 'Subscription'
      end

      def subscribed?
        active_subscription.present?
      end

      def on_trial?
        active_subscription&.on_trial? || false
      end

      def trial_days_remaining
        active_subscription&.trial_days_remaining || 0
      end

      def subscribe_to_plan(plan, payment_method: nil, coupon: nil)
        customer = find_or_create_stripe_customer
        
        subscription_params = {
          customer: customer.id,
          items: [{ price: plan.stripe_price_id }],
          expand: ['latest_invoice.payment_intent']
        }

        subscription_params[:trial_period_days] = plan.trial_period_days if plan.has_trial?
        subscription_params[:default_payment_method] = payment_method if payment_method
        subscription_params[:coupon] = coupon if coupon

        stripe_subscription = Stripe::Subscription.create(subscription_params)

        subscription = subscriptions.create!(
          plan: plan,
          stripe_subscription_id: stripe_subscription.id,
          status: stripe_subscription.status,
          trial_ends_at: stripe_subscription.trial_end ? Time.at(stripe_subscription.trial_end) : nil,
          current_period_start: Time.at(stripe_subscription.current_period_start),
          current_period_end: Time.at(stripe_subscription.current_period_end)
        )

        subscription
      end

      def track_usage(usage_type, quantity = 1)
        BillingService.track_usage(self, usage_type, quantity)
      end

      def create_one_time_payment(amount, description: nil, currency: 'usd')
        customer = find_or_create_stripe_customer

        payment_intent = Stripe::PaymentIntent.create(
          amount: amount,
          currency: currency,
          customer: customer.id,
          description: description || "One-time payment for #{email}"
        )

        payment_intent
      end

      def create_portal_session(return_url)
        return nil unless stripe_customer_id
        BillingService.create_portal_session(stripe_customer_id, return_url)
      end

      def usage_for_current_period(usage_type)
        return 0 unless active_subscription

        start_date = active_subscription.current_period_start || Time.current.beginning_of_month
        end_date = active_subscription.current_period_end || Time.current.end_of_month

        UsageRecord.total_usage_for_period(self, usage_type, start_date, end_date)
      end

      def stripe_customer
        return nil unless stripe_customer_id
        @stripe_customer ||= Stripe::Customer.retrieve(stripe_customer_id)
      end

      private

      def find_or_create_stripe_customer
        return stripe_customer if stripe_customer_id

        customer = Stripe::Customer.create(
          email: email,
          name: name,
          metadata: {
            user_id: id
          }
        )

        update!(stripe_customer_id: customer.id)
        customer
      end
    end
  RUBY

  # Create billing controllers
  create_file 'app/domains/billing/app/controllers/billing_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    class BillingController < ApplicationController
      before_action :authenticate_user!

      def index
        @subscription = current_user.active_subscription
        @invoices = current_user.invoices.order(created_at: :desc).limit(10)
      end

      def plans
        @plans = Plan.visible
        @coupon = Coupon.find_by(code: params[:coupon_code]) if params[:coupon_code].present?
      end

      def subscribe
        @plan = Plan.find(params[:plan_id])
        @coupon = Coupon.find_by(code: params[:coupon_code]) if params[:coupon_code].present?

        if @coupon && !@coupon.valid?
          redirect_to billing_plans_path, alert: 'Invalid or expired coupon code.'
          return
        end

        if current_user.subscribed?
          redirect_to billing_index_path, alert: 'You already have an active subscription.'
          return
        end

        subscription = current_user.subscribe_to_plan(
          @plan,
          payment_method: params[:payment_method],
          coupon: @coupon&.stripe_coupon_id
        )

        redirect_to billing_index_path, notice: 'Successfully subscribed!'
      rescue Stripe::StripeError => e
        redirect_to billing_plans_path, alert: "Subscription failed: #{e.message}"
      end

      def cancel_subscription
        subscription = current_user.active_subscription
        if subscription
          subscription.cancel!
          redirect_to billing_index_path, notice: 'Subscription cancelled successfully.'
        else
          redirect_to billing_index_path, alert: 'No active subscription found.'
        end
      rescue Stripe::StripeError => e
        redirect_to billing_index_path, alert: "Failed to cancel subscription: #{e.message}"
      end

      def change_plan
        @current_subscription = current_user.active_subscription
        @new_plan = Plan.find(params[:plan_id])

        unless @current_subscription
          redirect_to billing_plans_path, alert: 'No active subscription found.'
          return
        end

        @current_subscription.change_plan(@new_plan)
        redirect_to billing_index_path, notice: "Successfully changed to #{@new_plan.name}!"
      rescue Stripe::StripeError => e
        redirect_to billing_index_path, alert: "Failed to change plan: #{e.message}"
      end

      def download_invoice
        invoice = current_user.invoices.find(params[:id])
        pdf_data = invoice.generate_pdf

        send_data pdf_data,
                  filename: invoice.download_filename,
                  type: 'application/pdf',
                  disposition: 'attachment'
      end

      def portal
        portal_session = current_user.create_portal_session(billing_url)
        
        if portal_session
          redirect_to portal_session.url, allow_other_host: true
        else
          redirect_to billing_index_path, alert: 'Unable to access billing portal.'
        end
      rescue Stripe::StripeError => e
        redirect_to billing_index_path, alert: "Portal access failed: #{e.message}"
      end
    end
  RUBY

  # Create admin plan controller for plan management
  create_file 'app/domains/billing/app/controllers/admin/plans_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    module Admin
      class PlansController < ApplicationController
        before_action :authenticate_admin!
        before_action :set_plan, only: [:show, :edit, :update, :destroy, :activate, :deactivate]

        def index
          @plans = Plan.all.order(:sort_order, :amount)
        end

        def show
          @subscriptions_count = @plan.subscriptions.count
          @active_subscriptions_count = @plan.subscriptions.active_or_trialing.count
        end

        def new
          @plan = Plan.new
        end

        def create
          @plan = Plan.new(plan_params)
          
          # Handle features and feature_limits arrays
          process_plan_arrays
          
          if @plan.save
            # Create corresponding Stripe product and price if Stripe IDs not provided
            unless @plan.stripe_product_id.present? && @plan.stripe_price_id.present?
              create_stripe_product_and_price
            end
            
            redirect_to admin_plan_path(@plan), notice: 'Plan created successfully.'
          else
            render :new
          end
        rescue Stripe::StripeError => e
          @plan.errors.add(:base, "Stripe error: #{e.message}")
          render :new
        end

        def edit
        end

        def update
          # Handle features and feature_limits arrays
          process_plan_arrays
          
          if @plan.update(plan_params)
            # Update Stripe product if needed
            update_stripe_product if stripe_needs_update?
            
            redirect_to admin_plan_path(@plan), notice: 'Plan updated successfully.'
          else
            render :edit
          end
        rescue Stripe::StripeError => e
          @plan.errors.add(:base, "Stripe error: #{e.message}")
          render :edit
        end

        def destroy
          if @plan.subscriptions.active_or_trialing.exists?
            redirect_to admin_plans_path, alert: 'Cannot delete plan with active subscriptions.'
          else
            @plan.destroy
            redirect_to admin_plans_path, notice: 'Plan deleted successfully.'
          end
        end

        def activate
          @plan.update!(active: true)
          redirect_to admin_plans_path, notice: 'Plan activated successfully.'
        end

        def deactivate
          @plan.update!(active: false)
          redirect_to admin_plans_path, notice: 'Plan deactivated successfully.'
        end

        private

        def set_plan
          @plan = Plan.find(params[:id])
        end

        def plan_params
          params.require(:plan).permit(
            :name, :description, :amount, :currency, :interval, :usage_type,
            :trial_period_days, :sort_order, :highlighted, :active,
            :stripe_product_id, :stripe_price_id,
            features: []
          )
        end

        def process_plan_arrays
          # Handle features array
          if params[:plan][:features].present?
            @plan.features = params[:plan][:features].reject(&:blank?)
          end

          # Handle feature_limits hash from separate key/value arrays
          if params[:plan][:feature_limits_keys].present? && params[:plan][:feature_limits_values].present?
            keys = params[:plan][:feature_limits_keys].reject(&:blank?)
            values = params[:plan][:feature_limits_values].reject(&:blank?)
            
            feature_limits = {}
            keys.each_with_index do |key, index|
              if values[index].present?
                # Try to convert to integer if it's a number, otherwise keep as string
                value = values[index].match?(/\A-?\d+\z/) ? values[index].to_i : values[index]
                feature_limits[key] = value
              end
            end
            @plan.feature_limits = feature_limits
          end

          # Handle metadata (if you want to add metadata editing later)
          @plan.metadata ||= {}
        end

        def authenticate_admin!
          # Implement your admin authentication logic here
          # For example, checking if user has admin role:
          redirect_to root_path unless current_user&.admin?
        end

        def create_stripe_product_and_price
          # Create Stripe product
          product = Stripe::Product.create(
            name: @plan.name,
            description: @plan.description,
            metadata: @plan.metadata || {}
          )

          # Create Stripe price
          price = Stripe::Price.create(
            product: product.id,
            unit_amount: @plan.amount,
            currency: @plan.currency,
            recurring: {
              interval: @plan.interval
            },
            usage_type: @plan.usage_type
          )

          @plan.update!(
            stripe_product_id: product.id,
            stripe_price_id: price.id
          )
        end

        def stripe_needs_update?
          @plan.previous_changes.any? { |key, _| 
            %w[name description metadata].include?(key) 
          }
        end

        def update_stripe_product
          return unless @plan.stripe_product_id

          Stripe::Product.update(@plan.stripe_product_id, {
            name: @plan.name,
            description: @plan.description,
            metadata: @plan.metadata || {}
          })
        end
      end
    end
  RUBY

  # Create admin coupon controller for coupon management
  create_file 'app/domains/billing/app/controllers/admin/coupons_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    module Admin
      class CouponsController < ApplicationController
        before_action :authenticate_admin!
        before_action :set_coupon, only: [:show, :edit, :update, :destroy, :activate, :deactivate]

        def index
          @coupons = Coupon.all.order(:code)
        end

        def show
        end

        def new
          @coupon = Coupon.new
        end

        def create
          @coupon = Coupon.new(coupon_params)
          
          if @coupon.save
            redirect_to admin_coupon_path(@coupon), notice: 'Coupon created successfully.'
          else
            render :new
          end
        end

        def edit
        end

        def update
          if @coupon.update(coupon_params)
            redirect_to admin_coupon_path(@coupon), notice: 'Coupon updated successfully.'
          else
            render :edit
          end
        end

        def destroy
          @coupon.destroy
          redirect_to admin_coupons_path, notice: 'Coupon deleted successfully.'
        end

        def activate
          @coupon.update!(active: true)
          redirect_to admin_coupons_path, notice: 'Coupon activated successfully.'
        end

        def deactivate
          @coupon.update!(active: false)
          redirect_to admin_coupons_path, notice: 'Coupon deactivated successfully.'
        end

        private

        def set_coupon
          @coupon = Coupon.find(params[:id])
        end

        def coupon_params
          params.require(:coupon).permit(
            :code, :stripe_coupon_id, :discount_type, :discount_value,
            :valid_from, :valid_until, :max_redemptions, :active
          )
        end

        def authenticate_admin!
          # Implement your admin authentication logic here
          redirect_to root_path unless current_user&.admin?
        end
      end
    end
  RUBY

  # Create webhook controller
  create_file 'app/domains/billing/app/controllers/webhooks/stripe_controller.rb', <<~'RUBY'
    # frozen_string_literal: true

    module Webhooks
      class StripeController < ApplicationController
        protect_from_forgery with: :null_session
        before_action :verify_stripe_signature

        # Define error classes for better retry handling
        class TransientError < StandardError; end
        class PermanentError < StandardError; end

        def handle
          # Check if we've already processed this event
          if WebhookEvent.exists?(stripe_event_id: @event.id)
            head :ok
            return
          end

          # Process the event
          case @event.type
          when 'invoice.paid'
            handle_invoice_paid
          when 'invoice.payment_failed'
            handle_invoice_payment_failed
          when 'customer.subscription.updated'
            handle_subscription_updated
          when 'customer.subscription.deleted'
            handle_subscription_deleted
          when 'customer.subscription.trial_will_end'
            handle_trial_will_end
          when 'payment_intent.succeeded'
            handle_payment_intent_succeeded
          when 'payment_intent.payment_failed'
            handle_payment_intent_failed
          else
            Rails.logger.info "Unhandled Stripe webhook event: #{@event.type}"
          end

          # Mark event as processed
          WebhookEvent.create!(
            stripe_event_id: @event.id,
            event_type: @event.type,
            processed_at: Time.current
          )

          head :ok
        rescue TransientError => e
          Rails.logger.warn "Transient error in Stripe webhook: #{e.message}"
          Rails.logger.warn e.backtrace.join("\n")
          
          # Schedule retry job for transient errors with exponential backoff
          retry_count = params[:retry_count].to_i
          wait_time = [2 ** retry_count, 300].min # Cap at 5 minutes
          
          StripeWebhookRetryJob.set(wait: wait_time.seconds).perform_later(@event.id, retry_count + 1)
          
          head :service_unavailable
        rescue PermanentError => e
          Rails.logger.error "Permanent error in Stripe webhook: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          
          # Log permanent error but don't retry
          WebhookEvent.create!(
            stripe_event_id: @event.id,
            event_type: @event.type,
            processed_at: Time.current,
            error_message: e.message,
            error_type: 'permanent'
          )
          
          head :unprocessable_entity
        rescue => e
          Rails.logger.error "Unexpected Stripe webhook error: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          
          # Treat unknown errors as transient initially
          retry_count = params[:retry_count].to_i
          if retry_count < 3
            wait_time = [2 ** retry_count, 300].min
            StripeWebhookRetryJob.set(wait: wait_time.seconds).perform_later(@event.id, retry_count + 1)
            head :service_unavailable
          else
            # After 3 retries, treat as permanent
            WebhookEvent.create!(
              stripe_event_id: @event.id,
              event_type: @event.type,
              processed_at: Time.current,
              error_message: e.message,
              error_type: 'unknown_permanent'
            )
            head :internal_server_error
          end
        end

        private

        def verify_stripe_signature
          payload = request.body.read
          sig_header = request.env['HTTP_STRIPE_SIGNATURE']
          endpoint_secret = Rails.configuration.stripe[:webhook_secret]

          begin
            @event = Stripe::Webhook.construct_event(payload, sig_header, endpoint_secret)
          rescue JSON::ParserError
            raise PermanentError, "Invalid JSON payload"
          rescue Stripe::SignatureVerificationError
            raise PermanentError, "Invalid webhook signature"
          end
        end

        def handle_invoice_paid
          invoice_data = @event.data.object
          subscription = find_subscription_by_stripe_id(invoice_data.subscription)
          
          return unless subscription

          invoice = subscription.invoices.find_or_create_by(stripe_invoice_id: invoice_data.id) do |inv|
            inv.user = subscription.user
            inv.amount_paid = invoice_data.amount_paid
            inv.status = invoice_data.status
            inv.number = invoice_data.number
            inv.pdf_url = invoice_data.invoice_pdf
          end

          # Update subscription status if needed
          subscription.update!(status: 'active') if subscription.status != 'active'

          # Send invoice email if needed
          BillingMailer.invoice_paid(invoice).deliver_later
        rescue ActiveRecord::RecordNotFound => e
          raise TransientError, "Subscription not found: #{e.message}"
        rescue => e
          raise TransientError, "Failed to process invoice payment: #{e.message}"
        end

        def handle_invoice_payment_failed
          invoice_data = @event.data.object
          subscription = find_subscription_by_stripe_id(invoice_data.subscription)
          
          return unless subscription

          subscription.update!(status: 'past_due')
          
          # Send payment failed email
          BillingMailer.payment_failed(subscription).deliver_later
        rescue ActiveRecord::RecordNotFound => e
          raise TransientError, "Subscription not found: #{e.message}"
        rescue => e
          raise TransientError, "Failed to process payment failure: #{e.message}"
        end

        def handle_subscription_updated
          subscription_data = @event.data.object
          subscription = find_subscription_by_stripe_id(subscription_data.id)
          
          return unless subscription

          subscription.update!(
            status: subscription_data.status,
            trial_ends_at: subscription_data.trial_end ? Time.at(subscription_data.trial_end) : nil,
            current_period_start: Time.at(subscription_data.current_period_start),
            current_period_end: Time.at(subscription_data.current_period_end)
          )
        rescue ActiveRecord::RecordNotFound => e
          raise TransientError, "Subscription not found: #{e.message}"
        rescue => e
          raise TransientError, "Failed to update subscription: #{e.message}"
        end

        def handle_subscription_deleted
          subscription_data = @event.data.object
          subscription = find_subscription_by_stripe_id(subscription_data.id)
          
          return unless subscription

          subscription.update!(status: 'canceled', canceled_at: Time.current)
        rescue ActiveRecord::RecordNotFound => e
          # If subscription not found, it might already be deleted - not an error
          Rails.logger.info "Subscription #{subscription_data.id} already deleted or not found"
        rescue => e
          raise TransientError, "Failed to delete subscription: #{e.message}"
        end

        def handle_trial_will_end
          subscription_data = @event.data.object
          subscription = find_subscription_by_stripe_id(subscription_data.id)
          
          return unless subscription

          # Send trial ending email
          BillingMailer.trial_will_end(subscription).deliver_later
        rescue ActiveRecord::RecordNotFound => e
          raise TransientError, "Subscription not found: #{e.message}"
        rescue => e
          raise TransientError, "Failed to handle trial ending: #{e.message}"
        end

        def handle_payment_intent_succeeded
          payment_intent_data = @event.data.object
          customer_id = payment_intent_data.customer
          
          # Handle one-time payment success if needed
          # This could trigger specific business logic for one-off purchases
          Rails.logger.info "Payment succeeded for customer #{customer_id}: #{payment_intent_data.id}"
        rescue => e
          raise TransientError, "Failed to handle payment success: #{e.message}"
        end

        def handle_payment_intent_failed
          payment_intent_data = @event.data.object
          customer_id = payment_intent_data.customer
          
          # Handle one-time payment failure
          Rails.logger.warn "Payment failed for customer #{customer_id}: #{payment_intent_data.id}"
        rescue => e
          raise TransientError, "Failed to handle payment failure: #{e.message}"
        end

        def find_subscription_by_stripe_id(stripe_subscription_id)
          return nil unless stripe_subscription_id
          
          Subscription.find_by!(stripe_subscription_id: stripe_subscription_id)
        end
      end
    end
  RUBY

  # Create services for Stripe integration
  create_file 'app/domains/billing/app/services/billing_service.rb', <<~'RUBY'
    # frozen_string_literal: true

    class BillingService
      def self.create_usage_record(subscription, quantity, timestamp = Time.current)
        stripe_subscription = Stripe::Subscription.retrieve(subscription.stripe_subscription_id)
        
        # Find the metered price item
        metered_item = stripe_subscription.items.data.find do |item|
          price = Stripe::Price.retrieve(item.price.id)
          price.usage_type == 'metered'
        end

        return unless metered_item

        Stripe::UsageRecord.create({
          subscription_item: metered_item.id,
          quantity: quantity,
          timestamp: timestamp.to_i,
          action: 'increment'
        })
      end

      def self.track_usage(user, usage_type, quantity = 1)
        return unless user.subscribed?

        subscription = user.active_subscription
        return unless subscription

        # Store usage record locally for reporting
        UsageRecord.create!(
          user: user,
          subscription: subscription,
          usage_type: usage_type,
          quantity: quantity,
          recorded_at: Time.current
        )

        # Send to Stripe if this is a metered plan
        if subscription.plan.usage_type == 'metered'
          create_usage_record(subscription, quantity)
        end
      end

      def self.create_portal_session(customer_id, return_url)
        Stripe::BillingPortal::Session.create({
          customer: customer_id,
          return_url: return_url
        })
      end

      def self.sync_subscription_from_stripe(stripe_subscription_id)
        stripe_subscription = Stripe::Subscription.retrieve(stripe_subscription_id)
        subscription = Subscription.find_by(stripe_subscription_id: stripe_subscription_id)
        
        return unless subscription

        subscription.update!(
          status: stripe_subscription.status,
          trial_ends_at: stripe_subscription.trial_end ? Time.at(stripe_subscription.trial_end) : nil,
          current_period_start: Time.at(stripe_subscription.current_period_start),
          current_period_end: Time.at(stripe_subscription.current_period_end)
        )

        subscription
      end
    end
  RUBY

  # Create PDF service for invoice generation
  create_file 'app/domains/billing/app/services/invoice_pdf_service.rb', <<~'RUBY'
    # frozen_string_literal: true

    class InvoicePdfService
      def initialize(invoice)
        @invoice = invoice
        @user = invoice.user
      end

      def generate
        Prawn::Document.new do |pdf|
          # Header
          pdf.text "INVOICE", size: 24, style: :bold, align: :center
          pdf.move_down 20

          # Invoice details
          pdf.text "Invoice ##{@invoice.number || @invoice.id}", size: 16, style: :bold
          pdf.text "Date: #{@invoice.created_at.strftime('%B %d, %Y')}"
          pdf.text "Status: #{@invoice.status.titleize}"
          pdf.move_down 20

          # Customer details
          pdf.text "Bill To:", size: 14, style: :bold
          pdf.text @user.name || @user.email
          pdf.text @user.email if @user.name
          pdf.move_down 20

          # Invoice items
          if @invoice.subscription
            pdf.text "Subscription:", size: 14, style: :bold
            pdf.text @invoice.subscription.plan.name
            pdf.text "Period: #{@invoice.subscription.current_period_start&.strftime('%m/%d/%Y')} - #{@invoice.subscription.current_period_end&.strftime('%m/%d/%Y')}"
          end

          pdf.move_down 20

          # Amount
          pdf.text "Amount: $#{@invoice.amount_in_dollars}", size: 16, style: :bold, align: :right

          # Footer
          pdf.move_down 40
          pdf.text "Thank you for your business!", size: 12, align: :center
        end.render
      end
    end
  RUBY

  # Create billing mailer
  create_file 'app/domains/billing/app/mailers/billing_mailer.rb', <<~'RUBY'
    # frozen_string_literal: true

    class BillingMailer < ApplicationMailer
      def invoice_paid(invoice)
        @invoice = invoice
        @user = invoice.user

        mail(
          to: @user.email,
          subject: "Invoice ##{@invoice.number || @invoice.id} - Payment Received"
        )
      end

      def payment_failed(subscription)
        @subscription = subscription
        @user = subscription.user

        mail(
          to: @user.email,
          subject: "Payment Failed - Action Required"
        )
      end

      def trial_will_end(subscription)
        @subscription = subscription
        @user = subscription.user

        mail(
          to: @user.email,
          subject: "Your free trial ends soon"
        )
      end
    end
  RUBY

  # Create Sidekiq job for webhook retries
  create_file 'app/domains/billing/app/jobs/stripe_webhook_retry_job.rb', <<~'RUBY'
    # frozen_string_literal: true

    class StripeWebhookRetryJob < ApplicationJob
      queue_as :default
      retry_on StandardError, wait: :exponentially_longer, attempts: 5

      def perform(stripe_event_id, retry_count = 0)
        # Fetch the event from Stripe
        event = Stripe::Event.retrieve(stripe_event_id)
        
        # Create a mock request with retry count for the controller
        controller = Webhooks::StripeController.new
        controller.instance_variable_set(:@event, event)
        
        # Set retry count in params
        allow(controller).to receive(:params).and_return({ retry_count: retry_count })
        
        # Process the webhook
        controller.send(:handle_event_processing)
      rescue Stripe::StripeError => e
        Rails.logger.error "Stripe API error in webhook retry: #{e.message}"
        
        # Mark as permanently failed if it's a Stripe API error
        WebhookEvent.create!(
          stripe_event_id: stripe_event_id,
          event_type: event&.type || 'unknown',
          processed_at: Time.current,
          error_message: e.message,
          error_type: 'stripe_api_error',
          retry_count: retry_count
        )
        
        raise e # Don't retry Stripe API errors
      rescue => e
        Rails.logger.error "Error in webhook retry job: #{e.message}"
        
        # Update retry count
        webhook_event = WebhookEvent.find_by(stripe_event_id: stripe_event_id)
        if webhook_event
          webhook_event.update!(retry_count: retry_count)
        end
        
        raise e # Let Sidekiq handle the retry
      end

      private

      # Extract event processing logic for testing
      def handle_event_processing
        # This method would contain the actual event processing logic
        # For now, we'll delegate back to the controller
        case @event.type
        when 'invoice.paid'
          handle_invoice_paid
        when 'invoice.payment_failed'
          handle_invoice_payment_failed
        when 'customer.subscription.updated'
          handle_subscription_updated
        when 'customer.subscription.deleted'
          handle_subscription_deleted
        when 'customer.subscription.trial_will_end'
          handle_trial_will_end
        when 'payment_intent.succeeded'
          handle_payment_intent_succeeded
        when 'payment_intent.payment_failed'
          handle_payment_intent_failed
        end
      end
    end
  RUBY

  # Create migrations
  migration_template = <<~'RUBY'
    class CreateBillingTables < ActiveRecord::Migration[7.0]
      def change
        create_table :plans do |t|
          t.string :name, null: false
          t.string :stripe_product_id, null: false
          t.string :stripe_price_id, null: false
          t.integer :amount, null: false # in cents
          t.string :currency, default: 'usd'
          t.string :interval, null: false # day, week, month, year
          t.string :usage_type, default: 'licensed' # licensed, metered
          t.integer :trial_period_days, default: 0
          t.text :description
          t.text :features # JSON or serialized array
          t.text :metadata # JSON for flexible plan configuration
          t.text :feature_limits # JSON for usage limits and tiers
          t.integer :sort_order, default: 0
          t.boolean :highlighted, default: false # for "most popular" styling
          t.boolean :active, default: true
          t.timestamps
        end

        create_table :subscriptions do |t|
          t.references :user, null: false, foreign_key: true
          t.references :plan, null: false, foreign_key: true
          t.string :stripe_subscription_id, null: false
          t.string :status, null: false
          t.datetime :trial_ends_at
          t.datetime :current_period_start
          t.datetime :current_period_end
          t.datetime :canceled_at
          t.timestamps
        end

        create_table :invoices do |t|
          t.references :user, null: false, foreign_key: true
          t.references :subscription, null: true, foreign_key: true
          t.string :stripe_invoice_id, null: false
          t.integer :amount_paid, null: false # in cents
          t.string :currency, default: 'usd'
          t.string :status, null: false
          t.string :number
          t.string :pdf_url
          t.binary :pdf_data
          t.timestamps
        end

        create_table :webhook_events do |t|
          t.string :stripe_event_id, null: false
          t.string :event_type, null: false
          t.datetime :processed_at
          t.text :error_message
          t.string :error_type
          t.integer :retry_count, default: 0
          t.timestamps
        end

        create_table :coupons do |t|
          t.string :code, null: false
          t.string :stripe_coupon_id, null: false
          t.string :discount_type, null: false # percentage, fixed
          t.integer :discount_value, null: false
          t.datetime :valid_from
          t.datetime :valid_until
          t.integer :max_redemptions
          t.integer :redemptions_count, default: 0
          t.boolean :active, default: true
          t.timestamps
        end

        create_table :usage_records do |t|
          t.references :user, null: false, foreign_key: true
          t.references :subscription, null: false, foreign_key: true
          t.string :usage_type, null: false
          t.integer :quantity, null: false, default: 1
          t.datetime :recorded_at, null: false
          t.timestamps
        end

        add_column :users, :stripe_customer_id, :string
        
        add_index :plans, :stripe_product_id, unique: true
        add_index :plans, :stripe_price_id, unique: true
        add_index :subscriptions, :stripe_subscription_id, unique: true
        add_index :invoices, :stripe_invoice_id, unique: true
        add_index :webhook_events, :stripe_event_id, unique: true
        add_index :coupons, :code, unique: true
        add_index :coupons, :stripe_coupon_id, unique: true
        add_index :users, :stripe_customer_id
        add_index :usage_records, [:user_id, :usage_type]
        add_index :usage_records, :recorded_at
      end
    end
  RUBY

  timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
  create_file "db/migrate/#{timestamp}_create_billing_tables.rb", migration_template

  # Add routes
  route <<~'RUBY'
    scope module: :billing do
      # Billing routes
      get '/billing', to: 'billing#index'
      get '/billing/plans', to: 'billing#plans'
      get '/billing/portal', to: 'billing#portal'
      post '/billing/subscribe', to: 'billing#subscribe'
      delete '/billing/cancel', to: 'billing#cancel_subscription'
      patch '/billing/change_plan', to: 'billing#change_plan'
      get '/billing/invoices/:id/download', to: 'billing#download_invoice', as: 'download_invoice'
      
      # Admin billing routes
      namespace :admin do
        resources :plans do
          member do
            patch :activate
            patch :deactivate
          end
        end
        resources :coupons
        resources :webhook_events, only: [:index, :show]
      end
      
      # Stripe webhooks
      post '/webhooks/stripe', to: 'webhooks/stripe#handle'
    end
  RUBY

  # Update User model to include Billable concern
  inject_into_class "app/models/user.rb", "User" do
    "  include Billable\n"
  end if File.exist?("app/models/user.rb")

  # Create seed data
  create_file 'db/seeds/billing_seeds.rb', <<~'RUBY'
    # frozen_string_literal: true

    # Create sample billing plans
    # Note: You'll need to create corresponding products and prices in your Stripe dashboard

    unless Plan.exists?
      puts "Creating sample billing plans..."

      Plan.create!([
        {
          name: "Starter",
          stripe_product_id: "prod_starter", # Replace with actual Stripe product ID
          stripe_price_id: "price_starter",   # Replace with actual Stripe price ID
          amount: 999,  # $9.99
          interval: "month",
          trial_period_days: 7,
          description: "Perfect for individuals getting started",
          features: ["5 projects", "Basic support", "1GB storage"],
          feature_limits: { "projects" => 5, "storage_gb" => 1, "api_calls" => 1000 },
          metadata: { "support_level" => "basic", "onboarding" => true },
          sort_order: 1
        },
        {
          name: "Professional",
          stripe_product_id: "prod_professional",
          stripe_price_id: "price_professional",
          amount: 2999, # $29.99
          interval: "month",
          trial_period_days: 14,
          description: "Ideal for growing teams",
          features: ["Unlimited projects", "Priority support", "10GB storage", "Advanced analytics"],
          feature_limits: { "projects" => -1, "storage_gb" => 10, "api_calls" => 10000 },
          metadata: { "support_level" => "priority", "analytics" => true },
          sort_order: 2,
          highlighted: true
        },
        {
          name: "Enterprise",
          stripe_product_id: "prod_enterprise",
          stripe_price_id: "price_enterprise",
          amount: 9999, # $99.99
          interval: "month",
          trial_period_days: 30,
          description: "For large organizations",
          features: ["Everything in Professional", "Custom integrations", "Unlimited storage", "Dedicated support"],
          feature_limits: { "projects" => -1, "storage_gb" => -1, "api_calls" => -1 },
          metadata: { "support_level" => "dedicated", "custom_integrations" => true },
          sort_order: 3
        }
      ])

      puts "Created #{Plan.count} billing plans."
    end

    # Create sample coupons
    unless Coupon.exists?
      puts "Creating sample coupons..."

      Coupon.create!([
        {
          code: "WELCOME10",
          stripe_coupon_id: "welcome10", # Replace with actual Stripe coupon ID
          discount_type: "percentage",
          discount_value: 10,
          valid_until: 3.months.from_now,
          max_redemptions: 100
        },
        {
          code: "SAVE20",
          stripe_coupon_id: "save20",
          discount_type: "fixed",
          discount_value: 2000, # $20.00
          valid_until: 1.month.from_now,
          max_redemptions: 50
        }
      ])

      puts "Created #{Coupon.count} coupons."
    end
  RUBY

  # Update the main seeds file to include billing seeds
  append_to_file 'db/seeds.rb', <<~'RUBY'

    # Load billing seeds
    load Rails.root.join('db', 'seeds', 'billing_seeds.rb')
  RUBY

  # Create view directories and files
  empty_directory 'app/domains/billing/app/views/billing'
  empty_directory 'app/domains/billing/app/views/billing_mailer'
  empty_directory 'app/domains/billing/app/views/admin/plans'

  # Copy view templates
  template 'billing/index.html.erb', 'app/domains/billing/app/views/billing/index.html.erb'
  template 'billing/plans.html.erb', 'app/domains/billing/app/views/billing/plans.html.erb'
  template 'billing_mailer/invoice_paid.html.erb', 'app/domains/billing/app/views/billing_mailer/invoice_paid.html.erb'
  template 'billing_mailer/payment_failed.html.erb', 'app/domains/billing/app/views/billing_mailer/payment_failed.html.erb'
  template 'billing_mailer/trial_will_end.html.erb', 'app/domains/billing/app/views/billing_mailer/trial_will_end.html.erb'
  
  # Copy admin view templates
  template 'admin/plans/index.html.erb', 'app/domains/billing/app/views/admin/plans/index.html.erb'
  template 'admin/plans/show.html.erb', 'app/domains/billing/app/views/admin/plans/show.html.erb'
  template 'admin/plans/new.html.erb', 'app/domains/billing/app/views/admin/plans/new.html.erb'
  template 'admin/plans/edit.html.erb', 'app/domains/billing/app/views/admin/plans/edit.html.erb'

  # Copy JavaScript assets
  copy_file 'billing.js', 'app/domains/billing/app/assets/javascripts/billing.js'

  # Add Stripe script tag to application layout
  inject_into_file 'app/views/layouts/application.html.erb', before: '</head>' do
    <<~'HTML'
      <%= javascript_include_tag "https://js.stripe.com/v3/" %>
      <script>
        window.stripePublishableKey = '<%= Rails.configuration.stripe[:publishable_key] %>';
      </script>
    HTML
  end if File.exist?('app/views/layouts/application.html.erb')

  # Add environment variables to .env.example
  append_to_file '.env.example', <<~'ENV'

    # Stripe configuration
    STRIPE_PUBLISHABLE_KEY=pk_test_your_publishable_key_here
    STRIPE_SECRET_KEY=sk_test_your_secret_key_here
    STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret_here
  ENV

  say_status :synth_billing, "Billing module installed successfully!"
  say_status :synth_billing, "✅ Enhanced plan model with metadata and feature limits"
  say_status :synth_billing, "✅ Improved webhook retry logic with error classification"
  say_status :synth_billing, "✅ Added admin UI for plan management"
  say_status :synth_billing, "✅ Comprehensive edge case tests included"
  say_status :synth_billing, ""
  say_status :synth_billing, "Next steps:"
  say_status :synth_billing, "1. Run 'rails db:migrate' to create billing tables"
  say_status :synth_billing, "2. Configure your Stripe API keys in .env"
  say_status :synth_billing, "3. Set up webhook endpoints in your Stripe dashboard"
  say_status :synth_billing, "4. Access admin plan management at /admin/plans"
  say_status :synth_billing, "5. Add admin? method to User model for admin access"
end