# Billing Module

Provides Stripe-based billing and subscription management.

## Features

- **Subscription Management**: Create, update, and cancel subscriptions
- **One-off Payments**: Support for single purchases
- **Metered Billing**: Usage-based pricing with automatic invoicing
- **Coupons & Discounts**: Promotional codes and discounts
- **PDF Invoices**: Automatically generated invoice PDFs
- **Webhook Handling**: Secure Stripe webhook processing

## Installation

```sh
bin/synth add billing
```

This will add models for customers, subscriptions, invoices, and payment methods, plus controllers for managing billing flows.

## Environment Variables

Required environment variables:
- `STRIPE_PUBLISHABLE_KEY`
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`