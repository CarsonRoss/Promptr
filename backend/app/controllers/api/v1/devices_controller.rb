module Api
  module V1
    class DevicesController < ApplicationController

      # GET /api/v1/device/status
      def status
        device = load_or_init_device
        render json: { paid: device.paid?, remaining_uses: device.remaining_uses }
      end

      # GET /api/v1/device/reset (development/test only)
      def reset
        return head :forbidden unless Rails.env.development? || Rails.env.test?
        dev = load_or_init_device
        dev.update!(remaining_uses: 20, paid: false)
        render json: { ok: true, remaining_uses: dev.remaining_uses, paid: dev.paid }
      end

      private

      def load_or_init_device
        device_id = request.headers['X-Device-Id'].to_s.presence || params[:device_id].to_s
        dev = Device.find_or_initialize_by(device_id: device_id.presence || fallback_id)
        dev.last_seen_at = Time.current
        dev.save! if dev.changed?
        dev
      end

      def fallback_id
        "anon-#{request.remote_ip}-#{request.user_agent.to_s[0..20]}"
      end
    end
  end
end


