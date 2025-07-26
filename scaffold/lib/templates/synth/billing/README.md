# Billing Module

This module provides comprehensive billing and subscription management using Stripe, including subscription plans, payment processing, invoicing, and webhook handling.

## Features

- **Stripe Integration**: Complete Stripe API integration for payments and subscriptions
- **Subscription Management**: Plan-based subscriptions with trial periods
- **Invoice Generation**: PDF invoice generation and management
- **Payment Methods**: Secure payment method storage and management
- **Webhook Handling**: Real-time webhook processing for payment events
- **Multi-Currency Support**: Support for multiple currencies via Money gem

## Installation

```bash
bin/synth add billing
```

This installs:
- Stripe gem and configuration
- Money-rails for currency handling
- Prawn for PDF generation
- Billing models (Plan, Subscription, Invoice, PaymentMethod)
- Billing service and webhook handlers

## Post-Installation

1. **Run migrations:**
   ```bash
   rails db:migrate
   ```

2. **Configure Stripe credentials:**
   ```bash
   rails credentials:edit
   ```
   Add:
   ```yaml
   stripe:
     publishable_key: pk_test_...
     secret_key: sk_test_...
     webhook_secret: whsec_...
   ```

3. **Add routes:**
   ```ruby
   resources :subscriptions, only: [:index, :show, :create, :update] do
     member do
       patch :cancel
     end
   end
   resources :billing, only: [:index]
   post '/webhooks/stripe', to: 'webhooks#stripe'
   ```

4. **Add Stripe customer ID to User model:**
   ```bash
   rails generate migration AddStripeCustomerIdToUsers stripe_customer_id:string
   ```

## Usage

### Creating Plans
```ruby
plan = Plan.create!(
  name: "Pro Plan",
  stripe_price_id: "price_1234567890",
  amount_cents: 2000,
  currency: "usd",
  interval: "month",
  trial_period_days: 14,
  features: ["Feature 1", "Feature 2"],
  active: true
)
```

### Managing Subscriptions
```ruby
# Create subscription
billing_service = BillingService.new(current_user)
subscription = billing_service.create_subscription(plan, payment_method_id)

# Cancel subscription
billing_service.cancel_subscription(subscription)

# Update payment method
billing_service.update_payment_method(new_payment_method_id)
```

### Generating Invoices
```ruby
pdf_content = BillingService.new(user).generate_invoice_pdf(invoice)
send_data pdf_content, filename: "invoice_#{invoice.id}.pdf", type: "application/pdf"
```

## Webhook Events

The module handles these Stripe webhook events:
- `invoice.payment_succeeded`
- `invoice.payment_failed`
- `customer.subscription.updated`
- `customer.subscription.deleted`

## Security

- Webhook signature verification
- CSRF protection bypass for webhooks only
- Secure payment method tokenization via Stripe

## Testing

```bash
bin/synth test billing
```

Use Stripe's test mode and webhook CLI for local development.

## Version

Current version: 1.0.0