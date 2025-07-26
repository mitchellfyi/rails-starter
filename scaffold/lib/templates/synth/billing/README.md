# Billing Module

Provides comprehensive billing and subscription management with Stripe integration.

## Features

- **Subscription Plans**: Free trials, monthly/annual subscriptions with different feature tiers
- **One-time Products**: Credits, services, and other one-off purchases  
- **Metered Billing**: Pay-per-use pricing for API requests and premium features
- **Coupons & Discounts**: Percentage and fixed-amount discounts with flexible rules
- **Usage Tracking**: Monitor and bill for metered services

## Models

- `Plan`: Subscription plans with pricing and features
- `Product`: One-time purchases and metered billing items
- `Subscription`: User subscriptions with status tracking
- `Coupon`: Discount codes and promotions
- `UsageRecord`: Usage tracking for metered billing
- `Invoice`: Invoice records and payment tracking

## Seed Data

The billing seeds create:

- **Free Trial Plan**: 14-day trial with basic features
- **Starter Plan**: $29/month for individuals and small teams  
- **Professional Plan**: $99/month with advanced features
- **Enterprise Plan**: $499/month for large organizations
- **One-time Products**: AI credits, setup services, custom templates
- **Metered Products**: Pay-per-API-request and premium model usage
- **Sample Coupons**: Welcome offers, student discounts, seasonal promotions

## Installation

```sh
bin/synth add billing
```

## Configuration

Add your Stripe keys to `.env`:

```
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
```

## Usage

```ruby
# Create a subscription
subscription = user.subscriptions.create!(
  plan: Plan.find_by(name: 'Professional'),
  stripe_id: stripe_subscription.id
)

# Track usage for metered billing
UsageRecord.create!(
  subscription: subscription,
  product: Product.find_by(name: 'API Usage'),
  quantity: 150
)

# Apply a coupon
coupon = Coupon.find_by(name: 'WELCOME50')
# Apply to Stripe subscription...
```