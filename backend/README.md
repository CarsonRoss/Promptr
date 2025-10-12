## Stripe configuration (development)

Set the following env vars (e.g., in `backend/.env` which is already loaded by `config/boot.rb`):

```
STRIPE_SECRET_KEY=sk_test_xxx
STRIPE_PRICE_ID=price_xxx
STRIPE_WEBHOOK_SECRET=whsec_xxx
STRIPE_SUCCESS_URL=http://localhost:5173/?checkout=success
STRIPE_CANCEL_URL=http://localhost:5173/?checkout=cancel
```

# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
