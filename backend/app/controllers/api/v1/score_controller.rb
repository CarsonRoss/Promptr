module Api
  module V1
    class ScoreController < ApplicationController
      before_action :load_device!
      def create
        prompt = params[:prompt].to_s
        if prompt.strip.empty?
          return render json: { error: 'prompt is required' }, status: :unprocessable_entity
        end
        if @device.exhausted?
          return render json: { paywall: true, remaining_uses: @device.remaining_uses }, status: :payment_required
        end

        # Short-circuit duplicate exact prompts per device: do not score, do not decrement
        normalized = prompt.strip
        cache_key_prompt  = ["device:last_prompt", @device.device_id].join(':')
        cache_key_result  = ["device:last_result", @device.device_id].join(':')
        last_prompt = Rails.cache.read(cache_key_prompt)
        if last_prompt.present? && last_prompt == normalized
          if (cached = Rails.cache.read(cache_key_result)).present?
            return render json: cached
          else
            # No cached result; fall through and score
          end
        end

        result = PromptScoringService.call(prompt)
        # Only decrement on success
        @device.consume_trial! unless @device.paid?
        # Cache the last prompt/result for idempotency for a short window
        Rails.cache.write(cache_key_prompt, normalized, expires_in: 10.minutes)
        Rails.cache.write(cache_key_result, result, expires_in: 10.minutes)
        render json: result
      end

      private

      def load_device!
        device_id = request.headers['X-Device-Id'].to_s.presence || params[:device_id].to_s
        @device = Device.find_or_initialize_by(device_id: device_id.presence || anonymous_id)
        @device.last_seen_at = Time.current
        @device.save! if @device.changed?
      end

      def anonymous_id
        # fallback identifier if none provided; not ideal but prevents crash
        "anon-#{request.remote_ip}-#{request.user_agent.to_s[0..20]}"
      end
    end
  end
end


