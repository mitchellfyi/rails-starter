# Billing Module

This module provides subscription and payment processing for Rails applications.

## Features

- Stripe integration for payments
- Subscription management
- Usage-based billing
- Invoice generation
- Payment webhooks
- Customer portal integration

## Installation

This module is automatically installed when you run:

```bash
railsplan new myapp --billing
```

Or manually add it to an existing application:

```bash
railsplan add billing
```

## Configuration

Add your Stripe API keys to your `.env` file:

```bash
STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_publishable_key
STRIPE_SECRET_KEY=sk_test_your_stripe_secret_key
STRIPE_WEBHOOK_SECRET=whsec_your_webhook_secret
```

## Usage

The billing module provides several key components:

- **Subscriptions**: Manage user subscriptions and plans
- **Payments**: Process payments and handle webhooks
- **Invoicing**: Generate and manage invoices
- **Usage Tracking**: Monitor usage for metered billing

## Version

1.0.0 