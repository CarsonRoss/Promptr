module Api
  module V1
    class SubscriptionsController < ApplicationController
      before_action :load_device

      def status
        # Prefer live Stripe status when we have a customer id and user is paid
        if @device.paid? && @device.stripe_customer_id.present?
          begin
            if (sub = find_active_subscription(@device.stripe_customer_id))
              return render json: {
                active: true,
                current_period_end: Time.at(sub.current_period_end).utc.iso8601,
                cancel_at_period_end: sub.cancel_at_period_end ? true : false,
                cancelled_at: nil
              }
            end
          rescue Stripe::StripeError => e
            Rails.logger.warn("[Subscriptions#status] Stripe error: #{e.class} #{e.message}")
            # fall through to cache/fallback
          end
        end

        # Fallback to cached state (useful immediately after actions), or default heuristics
        cancel_flag_key = cache_key(@device.device_id, 'cancel_at_period_end')
        period_end_key  = cache_key(@device.device_id, 'current_period_end')
        cancel_at_period_end = Rails.cache.read(cancel_flag_key) ? true : false
        cached_period_end = Rails.cache.read(period_end_key)

        computed_period_end = @device.paid? ? 1.month.from_now.utc.iso8601 : nil
        current_period_end = cancel_at_period_end ? cached_period_end : computed_period_end

        render json: {
          active: @device.paid?,
          current_period_end: current_period_end,
          cancel_at_period_end: cancel_at_period_end,
          cancelled_at: nil
        }
      end

      def cancel
        # Require a paid device with a Stripe customer
        unless @device.paid? && @device.stripe_customer_id.present?
          return render json: { error: 'not_paid' }, status: :unprocessable_entity
        end

        begin
          sub = find_active_subscription(@device.stripe_customer_id)
          return render json: { error: 'no_active_subscription' }, status: :not_found unless sub

          updated = Stripe::Subscription.update(sub.id, cancel_at_period_end: true)
          access_until = Time.at(updated.current_period_end).utc.iso8601

          # Cache for UI responsiveness
          Rails.cache.write(cache_key(@device.device_id, 'cancel_at_period_end'), true, expires_in: 60.days)
          Rails.cache.write(cache_key(@device.device_id, 'current_period_end'), access_until, expires_in: 60.days)

          render json: { cancelled: true, access_until: access_until }
        rescue Stripe::StripeError => e
          Rails.logger.error("[Subscriptions#cancel] Stripe error: #{e.class} #{e.message}")
          render json: { error: 'stripe_error', message: e.message }, status: :bad_gateway
        rescue => e
          Rails.logger.error("[Subscriptions#cancel] error: #{e.class} #{e.message}")
          render json: { error: 'server_error' }, status: :internal_server_error
        end
      end

      private

      def load_device
        device_id = request.headers['X-Device-Id'].to_s.presence || params[:device_id].to_s
        @device = Device.find_or_initialize_by(device_id: device_id.presence || anonymous_id)
      end

      def anonymous_id
        "anon-#{request.remote_ip}-#{request.user_agent.to_s[0..20]}"
      end

      def cache_key(device_id, field)
        ["device", device_id.to_s, "subscription", field.to_s].join(':')
      end

      def find_active_subscription(customer_id)
        # Get the most relevant subscription for this customer
        list = Stripe::Subscription.list(customer: customer_id, status: 'active', limit: 1)
        sub = list.data.first
        return sub if sub
        # Fallback: include trialing as active access
        list2 = Stripe::Subscription.list(customer: customer_id, status: 'trialing', limit: 1)
        list2.data.first
      end
    end
  end
end
