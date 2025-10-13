module Api
  module V1
    class PaymentsController < ApplicationController

      # POST /api/v1/payments/checkout
      # Body: { device_id: "uuid" }
      def checkout
        device_id = params[:device_id].to_s.presence || request.headers['X-Device-Id']
        return render json: { error: 'device_id required' }, status: :bad_request unless device_id.present?

        device = Device.find_or_initialize_by(device_id: device_id)
        if device.paid?
          return render json: { error: 'already_paid' }, status: :conflict
        end

        success_url = ENV['STRIPE_SUCCESS_URL'].presence || default_success_url
        cancel_url  = ENV['STRIPE_CANCEL_URL'].presence  || default_cancel_url

        line_items = if ENV['STRIPE_PRICE_ID'].present?
          [ { price: ENV['STRIPE_PRICE_ID'], quantity: 1 } ]
        else
          amount_cents = (ENV['STRIPE_UNIT_AMOUNT'] || '500').to_i # $5 default
          product_name = ENV['STRIPE_PRODUCT_NAME'] || 'Monthly access'
          currency = (ENV['STRIPE_CURRENCY'] || 'usd')
          [ {
              price_data: {
                currency: currency,
                product_data: { name: product_name },
                unit_amount: amount_cents,
                recurring: { interval: 'month' }
              },
              quantity: 1
            } ]
        end

        session = Stripe::Checkout::Session.create(
          mode: 'subscription',
          line_items: line_items,
          success_url: success_url_with_session(success_url),
          cancel_url: cancel_url,
          metadata: { device_id: device_id }
        )

        # Cache the session id for this device so we can confirm without relying on the client param
        Rails.cache.write(["device:last_checkout_session", device_id].join(':'), session.id, expires_in: 20.minutes)

        render json: { url: session.url }
      rescue Stripe::StripeError => e
        Rails.logger.error("[Payments#checkout] Stripe error: #{e.class} #{e.message}")
        render json: { error: 'stripe_error', message: e.message }, status: :bad_gateway
      rescue => e
        Rails.logger.error("[Payments#checkout] Error: #{e.class} #{e.message}")
        render json: { error: 'server_error' }, status: :internal_server_error
      end

      private

      def default_origin
        ref = request.referer
        return 'http://localhost:5173' unless ref
        begin
          uri = URI.parse(ref)
          host_port = uri.port && ![80, 443].include?(uri.port) ? ":#{uri.port}" : ''
          "#{uri.scheme}://#{uri.host}#{host_port}"
        rescue
          'http://localhost:5173'
        end
      end

      def default_success_url
        default_origin + '/?checkout=success'
      end

      def default_cancel_url
        default_origin + '/?checkout=cancel'
      end

      def success_url_with_session(url)
        # Ensure the success URL includes the session_id placeholder for client-side confirmation
        uri = URI.parse(url) rescue nil
        return url unless uri
        q = URI.decode_www_form(uri.query.to_s)
        unless q.any? { |k,_| k == 'session_id' }
          q << ['session_id', '{CHECKOUT_SESSION_ID}']
        end
        uri.query = URI.encode_www_form(q)
        uri.to_s
      end

      public

      # POST /api/v1/payments/confirm
      # Body: { session_id: 'cs_test_...' }
      def confirm
        # Revert to simpler, previously working confirm flow
        sid = params[:session_id].to_s
        # If no session id provided or placeholder value, try cache via device header
        if sid.empty? || sid.include?('{CHECKOUT_SESSION_ID}')
          did = request.headers['X-Device-Id'].to_s
          cached = Rails.cache.read(["device:last_checkout_session", did].join(':'))
          sid = cached.to_s if cached.present?
        end
        return render json: { error: 'session_id missing' }, status: :bad_request if sid.blank?

        s = Stripe::Checkout::Session.retrieve(sid)
        device_id = s.respond_to?(:metadata) ? s.metadata['device_id'] : s['metadata'] && s['metadata']['device_id']
        return render json: { error: 'missing device_id' }, status: :unprocessable_entity unless device_id.present?

        device = Device.find_or_initialize_by(device_id: device_id)
        device.update!(paid: true, stripe_customer_id: (s.respond_to?(:customer) ? s.customer : s['customer']))
        render json: { paid: true }
      rescue Stripe::StripeError => e
        Rails.logger.error("[Payments#confirm] Stripe error: #{e.class} #{e.message}")
        render json: { error: 'stripe_error', message: e.message }, status: :bad_gateway
      rescue => e
        Rails.logger.error("[Payments#confirm] Error: #{e.class} #{e.message}")
        render json: { error: 'server_error' }, status: :internal_server_error
      end
    end
  end
end


