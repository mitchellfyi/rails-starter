# Billing Module

This module adds comprehensive Stripe billing integration to your Rails app. It includes support for trials, subscriptions, one-off payments, metered billing, coupons, and PDF invoices.

## Installation

Run the following command from your application root to install the billing module via the RailsPlan CLI:

```
bin/railsplan add billing
```

This command will add the necessary gems, copy configuration files, run migrations, and set up initial billing models and controllers.

## Features

- **Subscription Plans**: Configurable products and subscription plans for recurring billing
- **Free Trials**: Support for trial periods with automatic conversion to paid plans
- **Payment Types**: One-off payments, recurring subscriptions, and usage-based metered billing
- **Coupons**: Discount code handling with percentage and fixed amount discounts
- **PDF Invoices**: Automatic generation of PDF invoices for paid plans
- **Webhooks**: Stripe webhook handling with retry logic and exponential backoff
- **Plan Management**: Upgrading and downgrading between subscription plans
- **Security**: Secure API key handling and sandbox testing support

## Configuration

After installation, configure your Stripe API keys in your environment:

```bash
# .env
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

## Models

The billing module creates the following models:

- `Plan`: Represents subscription plans with pricing and features
- `Subscription`: User subscriptions with trial and billing status
- `Invoice`: Generated invoices with PDF support
- `WebhookEvent`: Stripe webhook event processing with idempotency

## Usage

### Creating Plans

```ruby
Plan.create!(
  name: "Pro Plan",
  stripe_product_id: "prod_...",
  stripe_price_id: "price_...",
  amount: 2999, # $29.99 in cents
  interval: "month",
  trial_period_days: 14
)
```

### Managing Subscriptions

```ruby
# Start a subscription
subscription = current_user.subscribe_to_plan(plan)

# Upgrade/downgrade
subscription.change_plan(new_plan)

# Cancel subscription
subscription.cancel!
```

## Testing

Run the billing module tests:

```
bin/railsplan test billing
```

All external Stripe API calls are mocked in tests to ensure deterministic results.

## Next Steps

After installation:

1. Configure your Stripe webhook endpoint in the Stripe dashboard
2. Set up your products and prices in Stripe
3. Create initial plans in your application
4. Test the integration in Stripe's test mode

Contributions and improvements are welcome. Keep this README up to date as the module evolves.