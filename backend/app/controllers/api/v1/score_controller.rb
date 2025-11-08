module Api
  module V1
    class ScoreController < ApplicationController
      before_action :load_device!
      def create
        prompt = params[:prompt].to_s
        return render json: { error: 'prompt is required' }, status: :unprocessable_entity if prompt.strip.empty?
      
        user = current_user_from_cookie
        paid = user&.status == 'paid' # unify with status endpoint
      
        # Enforce paywall only for not-paid users
        if !paid && @device.exhausted?
          return render json: { paywall: true, remaining_uses: @device.remaining_uses }, status: :payment_required
        end
      
        normalized = prompt.strip
        cache_key_prompt  = ["device:last_prompt", @device.device_id].join(':')
        cache_key_result  = ["device:last_result", @device.device_id].join(':')
        last_prompt = Rails.cache.read(cache_key_prompt)
      
        if last_prompt.present? && last_prompt == normalized
          if (cached = Rails.cache.read(cache_key_result)).present?
            @device.consume_trial!(force: true) unless paid
            return render json: cached
          end
        end
      
        result = PromptScoringService.call(prompt)
      
        @device.consume_trial!(force: true) unless paid
      
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
        "anon-#{request.remote_ip}-#{request.user_agent.to_s[0..20]}"
      end
    end
  end
end

