module Api
  module V1
    class AuthController < ApplicationController

      # POST /api/v1/auth/login
      # Body: { email: string, password: string }
      def login
        email = params[:email].to_s.downcase.strip
        password = params[:password].to_s
        user = User.find_by(email: email)
        unless user && AuthService.verify_password(user, password)
          return render json: { error: 'invalid_credentials' }, status: :unauthorized
        end
        token = AuthService.generate_jwt(user_id: user.id)
        render json: { token: token }
      end

      # POST /api/v1/auth/signup
      # Body: { email: string, password: string, password_confirmation?: string }
      def signup
        email = params[:email].to_s.downcase.strip
        password = params[:password].to_s
        password_confirmation = params[:password_confirmation].presence || password

        user = User.new(email: email, password: password, password_confirmation: password_confirmation, status: 'unpaid')
        if user.save
          # Send verification email (link + 6-digit code)
          EmailVerificationService.send_verification_email(user)
          render json: { created: true }
        else
          render json: { error: 'validation_failed', details: user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/auth/verify_email
      # Body: { token?: string, code?: string }
      # Supports either signed token link or 6-digit code from email
      def verify_email
        # First try 6-digit code path
        if params[:code].present? && params[:email].present?
          code = params[:code].to_s.strip
          email = params[:email].to_s.downcase.strip
          user = User.find_by(email: email)
          return render json: { error: 'invalid_code' }, status: :not_found unless user
          cached = Rails.cache.read(["user:verify_code", user.id].join(':')).to_s
          unless cached.present? && code.length == cached.length && ActiveSupport::SecurityUtils.secure_compare(cached, code)
            return render json: { error: 'invalid_code' }, status: :unprocessable_entity
          end
          user.verify_email!
          Rails.cache.delete(["user:verify_code", user.id].join(':'))
          return render json: { verified: true }
        end

        # Fallback to token path using cache (since specs shouldn't depend on Rails signed ids)
        token = params[:token].to_s
        return render json: { error: 'missing_token_or_code' }, status: :bad_request if token.blank?
        user_id = Rails.cache.read(["user:verify_token", token].join(':')).to_i
        return render json: { error: 'invalid_token' }, status: :unprocessable_entity if user_id <= 0
        user = User.find_by(id: user_id)
        return render json: { error: 'invalid_token' }, status: :not_found unless user
        user.verify_email!
        Rails.cache.delete(["user:verify_token", token].join(':'))
        render json: { verified: true }
      end

      # POST /api/v1/auth/resend_verification
      # Body: { email: string }
      def resend_verification
        email = params[:email].to_s.downcase.strip
        user = User.find_by(email: email)
        return render json: { error: 'not_found' }, status: :not_found unless user
        ok = EmailVerificationService.send_verification_email(user)
        if ok
          render json: { sent: true }
        else
          render json: { error: 'email_send_failed' }, status: :service_unavailable
        end
      end
    end
  end
end
