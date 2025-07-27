# frozen_string_literal: true

# Billing module main installer

say_status :railsplan_billing, "Installing Billing module"

# Load gem dependencies
load File.join(__dir__, 'install_modules', 'gems.rb')

after_bundle do
  # Create directory structure
  run 'mkdir -p app/domains/billing/app/controllers/billing'
  run 'mkdir -p app/domains/billing/app/models'
  run 'mkdir -p app/domains/billing/app/services'
  run 'mkdir -p app/domains/billing/app/views/billing'
  run 'mkdir -p app/domains/billing/app/jobs'
  
  # Set up configuration
  load File.join(__dir__, 'install_modules', 'config.rb')
  
  # Copy application files
  directory 'app', 'app/domains/billing/app', force: true
  
  # Copy configuration files  
  directory 'config', 'config', force: true
  
  # Create migrations
  generate "model", "SubscriptionPlan", "name:string", "stripe_price_id:string", "amount_cents:integer", "currency:string", "interval:string", "active:boolean"
  generate "model", "Subscription", "user:references", "subscription_plan:references", "stripe_subscription_id:string", "status:string", "current_period_start:datetime", "current_period_end:datetime", "trial_end:datetime"
  generate "model", "Invoice", "user:references", "stripe_invoice_id:string", "amount_cents:integer", "currency:string", "status:string", "paid_at:datetime"
  
  # Add routes
  route <<~RUBY
    # Billing module routes
    namespace :billing do
      resources :subscriptions, only: [:index, :show, :new, :create, :destroy] do
        member do
          post :cancel
          post :resume
        end
      end
      resources :invoices, only: [:index, :show]
      resources :cards, only: [:index, :create, :destroy]
      post '/webhook', to: 'webhooks#handle'
    end
  RUBY
  
  say_status :railsplan_billing, "✅ Billing module installed successfully!"
  say_status :railsplan_billing, "📝 Run 'rails db:migrate' to apply billing database changes"
  say_status :railsplan_billing, "🔧 Configure Stripe keys in your environment variables"
  say_status :railsplan_billing, "💳 Set up Stripe webhook endpoint at /billing/webhook"
end