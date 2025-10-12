# frozen_string_literal: true

if ENV['STRIPE_SECRET_KEY'] && !ENV['STRIPE_SECRET_KEY'].empty?
  require 'stripe'
  Stripe.api_key = ENV['STRIPE_SECRET_KEY']
  Stripe.api_version = '2024-06-20'
else
  Rails.logger.warn('[Stripe] STRIPE_SECRET_KEY not set; Stripe disabled in this environment') if defined?(Rails)
end


