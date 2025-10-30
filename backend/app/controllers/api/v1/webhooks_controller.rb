module Api
  module V1
    class WebhooksController < ApplicationController

      # POST /api/v1/webhooks/stripe
      def stripe
        raw_body = request.raw_post
        sig_header = request.env['HTTP_STRIPE_SIGNATURE']
        secret = ENV['STRIPE_WEBHOOK_SECRET']
        unless secret
          Rails.logger.error('[Stripe Webhook] STRIPE_WEBHOOK_SECRET not configured')
          return head :unprocessable_entity
        end

        event = Stripe::Webhook.construct_event(raw_body, sig_header, secret)

        case event['type']
        when 'checkout.session.completed'
          handle_checkout_completed(event)
        else
          Rails.logger.info("[Stripe Webhook] Ignored event type=#{event['type']}")
        end

        head :ok
      rescue JSON::ParserError, Stripe::SignatureVerificationError => e
        Rails.logger.warn("[Stripe Webhook] signature/json error: #{e.class} #{e.message}")
        head :bad_request
      rescue => e
        Rails.logger.error("[Stripe Webhook] error: #{e.class} #{e.message}")
        head :internal_server_error
      end

      private

      def handle_checkout_completed(event)
        session = event['data']['object']
        device_id = session.dig('metadata', 'device_id').to_s
        customer_id = session['customer']
        user_id = session.dig('metadata', 'user_id').to_s
      
        if user_id.present?
          if (user = User.find_by(id: user_id))
            user.update!(status: 'paid')
          end
        end
      
        if device_id.present?
          device = Device.find_or_initialize_by(device_id: device_id)
          device.update!(stripe_customer_id: customer_id)
        end
      end
    end
  end
end


