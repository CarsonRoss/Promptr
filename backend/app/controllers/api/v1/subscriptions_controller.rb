module Api
  module V1
    class SubscriptionsController < ApplicationController
      before_action :require_user

      def status
        active = @user.status == 'paid'
        cancel_flag_key = user_cache_key(@user.id, 'cancel_at_period_end')
        period_end_key  = user_cache_key(@user.id, 'current_period_end')
        cancel_flag_val = Rails.cache.read(cancel_flag_key)
        has_cached_cancel_flag = (cancel_flag_val == true || cancel_flag_val == false)
        cancel_at_period_end = cancel_flag_val ? true : false
        cached_period_end = Rails.cache.read(period_end_key)

        # Prefer cached state when present for immediate UI responsiveness after actions
        if has_cached_cancel_flag
          computed_period_end = active ? 1.month.from_now.utc.iso8601 : nil
          current_period_end = cancel_at_period_end ? cached_period_end : computed_period_end
          return render json: {
            active: active,
            current_period_end: current_period_end,
            cancel_at_period_end: cancel_at_period_end,
            cancelled_at: nil
          }
        end

        # Otherwise, try live Stripe status if we have a cached customer id
        if active && (cid = Rails.cache.read(["user", @user.id.to_s, "stripe_customer_id"].join(':')).to_s).present?
          begin
            if (sub = find_active_subscription(cid))
              return render json: {
                active: true,
                current_period_end: Time.at(sub.current_period_end).utc.iso8601,
                cancel_at_period_end: sub.cancel_at_period_end ? true : false,
                cancelled_at: nil
              }
            end
          rescue Stripe::StripeError => e
            Rails.logger.warn("[Subscriptions#status] Stripe error: #{e.class} #{e.message}")
          end
        end

        computed_period_end = active ? 1.month.from_now.utc.iso8601 : nil
        current_period_end = cancel_at_period_end ? cached_period_end : computed_period_end

        render json: {
          active: active,
          current_period_end: current_period_end,
          cancel_at_period_end: cancel_at_period_end,
          cancelled_at: nil
        }
      end

      def cancel
        unless @user.status == 'paid'
          return render json: { error: 'not_paid' }, status: :unprocessable_entity
        end
        customer_id = find_or_cache_customer_id(@user)
        return render json: { error: 'no_customer' }, status: :unprocessable_entity if customer_id.blank?

        begin
          sub = find_active_subscription(customer_id)
          return render json: { error: 'no_active_subscription' }, status: :not_found unless sub

          updated = Stripe::Subscription.update(sub.id, cancel_at_period_end: true)
          access_until = Time.at(updated.current_period_end).utc.iso8601

          Rails.cache.write(user_cache_key(@user.id, 'cancel_at_period_end'), true, expires_in: 60.days)
          Rails.cache.write(user_cache_key(@user.id, 'current_period_end'), access_until, expires_in: 60.days)

          render json: { cancelled: true, access_until: access_until }
        rescue Stripe::StripeError => e
          Rails.logger.error("[Subscriptions#cancel] Stripe error: #{e.class} #{e.message}")
          render json: { error: 'stripe_error', message: e.message }, status: :bad_gateway
        rescue => e
          Rails.logger.error("[Subscriptions#cancel] error: #{e.class} #{e.message}")
          render json: { error: 'server_error' }, status: :internal_server_error
        end
      end

      def reactivate
        customer_id = find_or_cache_customer_id(@user)
        return render json: { error: 'no_customer' }, status: :unprocessable_entity if customer_id.blank?

        begin
          sub = find_active_subscription(customer_id)
          return render json: { error: 'no_active_subscription' }, status: :not_found unless sub

          updated = Stripe::Subscription.update(sub.id, cancel_at_period_end: false)
          access_until = Time.at(updated.current_period_end).utc.iso8601

          Rails.cache.write(user_cache_key(@user.id, 'cancel_at_period_end'), false, expires_in: 60.days)
          Rails.cache.write(user_cache_key(@user.id, 'current_period_end'), access_until, expires_in: 60.days)

          begin
            @user.update!(status: 'paid') if @user.status != 'paid'
          rescue => e
            Rails.logger.warn("[Subscriptions#reactivate] failed to mark user paid: #{e.class} #{e.message}")
          end

          render json: { reactivated: true, access_until: access_until }
        rescue Stripe::StripeError => e
          Rails.logger.error("[Subscriptions#reactivate] Stripe error: #{e.class} #{e.message}")
          render json: { error: 'stripe_error', message: e.message }, status: :bad_gateway
        rescue => e
          Rails.logger.error("[Subscriptions#reactivate] error: #{e.class} #{e.message}")
          render json: { error: 'server_error' }, status: :internal_server_error
        end
      end

      private

      def require_user
        @user = current_user_from_cookie
        render json: { error: 'unauthenticated' }, status: :unauthorized unless @user
      end

      def user_cache_key(user_id, field)
        ["user", user_id.to_s, "subscription", field.to_s].join(':')
      end

      def find_active_subscription(customer_id)
        list = Stripe::Subscription.list(customer: customer_id, status: 'active', limit: 1)
        sub = list.data.first
        return sub if sub
        list2 = Stripe::Subscription.list(customer: customer_id, status: 'trialing', limit: 1)
        list2.data.first
      end

      def find_or_cache_customer_id(user)
        key = ["user", user.id.to_s, "stripe_customer_id"].join(':')
        cid = Rails.cache.read(key).to_s
        return cid if cid.present?
        begin
          # Fallback by email if cache is missing
          list = Stripe::Customer.list(email: user.email, limit: 1)
          cid = list.data.first&.id.to_s
          Rails.cache.write(key, cid, expires_in: 1.year) if cid.present?
          cid
        rescue => e
          Rails.logger.warn("[Subscriptions#find_or_cache_customer_id] lookup failed: #{e.class} #{e.message}")
          ''
        end
      end
    end
  end
end
