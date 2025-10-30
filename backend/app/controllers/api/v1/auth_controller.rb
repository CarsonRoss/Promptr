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
        # Also set as HttpOnly cookie for session-style auth from browser
        claims = AuthService.decode_jwt(token)
        set_auth_cookie(token, expires_at: (Time.at(claims[:exp]) rescue 30.days.from_now))
        render json: { token: token }
      end

      # POST /api/v1/auth/signup
      # Body: { email: string, password: string, password_confirmation?: string }
      def signup
        email = params[:email].to_s.downcase.strip
        password = params[:password].to_s
        password_confirmation = params[:password_confirmation].presence || password

        # Do not persist user yet; issue verification code to email
        if email.blank? || password.length < 8 || password != password_confirmation
          return render json: { error: 'validation_failed' }, status: :unprocessable_entity
        end
        ok = EmailVerificationService.send_code_to_email(email)
        return render json: { created: true, pending: true } if ok
        render json: { error: 'email_send_failed' }, status: :service_unavailable
      end

      # POST /api/v1/auth/verify_email
      # Body: { token?: string, code?: string }
      # Supports either signed token link or 6-digit code from email
      def verify_email
        # First try 6-digit code path
        if params[:code].present? && params[:email].present?
          code = params[:code].to_s.strip
          email = params[:email].to_s.downcase.strip
          cache_key_email = ["email:verify_code", email].join(':')
          cached = Rails.cache.read(cache_key_email).to_s
          Rails.logger.info("[Auth#verify_email] email=#{email} provided_code=#{code} cached_code=#{cached}")
          unless cached.present? && code.length == cached.length && ActiveSupport::SecurityUtils.secure_compare(cached, code)
            return render json: { error: 'invalid_code' }, status: :unprocessable_entity
          end
          # Create the user now that code is verified
          pwd = params[:password].to_s
          pwdc = params[:password_confirmation].presence || pwd

          return render json: { error: 'password_blank' }, status: :unprocessable_entity if pwd.blank?
          return render json: { error: 'password_too_short' }, status: :unprocessable_entity if pwd.length < 8
          return render json: { error: 'password_confirmation_mismatch' }, status: :unprocessable_entity if pwd != pwdc

          user = User.create!(email: email, password: pwd, password_confirmation: pwdc, status: 'unpaid')
          user.verify_email_timestamp!
          Rails.cache.delete(cache_key_email)
          # Auto sign-in: issue JWT cookie
          token = AuthService.generate_jwt(user_id: user.id)
          claims = AuthService.decode_jwt(token)
          set_auth_cookie(token, expires_at: (Time.at(claims[:exp]) rescue 30.days.from_now))
          return render json: { verified: true }
        end

        # Fallback to token path using cache (since specs shouldn't depend on Rails signed ids)
        token = params[:token].to_s
        return render json: { error: 'missing_token_or_code' }, status: :bad_request if token.blank?
        user_id = Rails.cache.read(["user:verify_token", token].join(':')).to_i
        return render json: { error: 'invalid_token' }, status: :unprocessable_entity if user_id <= 0
        user = User.find_by(id: user_id)
        return render json: { error: 'invalid_token' }, status: :not_found unless user
        user.verify_email_timestamp!
        Rails.cache.delete(["user:verify_token", token].join(':'))
        # Auto sign-in: issue JWT cookie
        token2 = AuthService.generate_jwt(user_id: user.id)
        claims2 = AuthService.decode_jwt(token2)
        set_auth_cookie(token2, expires_at: (Time.at(claims2[:exp]) rescue 30.days.from_now))
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

      # GET /api/v1/auth/session
      # Returns { authenticated: boolean, user?: {...} }
      def session
        user = current_user_from_cookie
        if user
          render json: { authenticated: true, user: { id: user.id, email: user.email, status: user.status, verified_at: user.verified_at } }
        else
          render json: { authenticated: false }
        end
      end

      # POST /api/v1/auth/logout
      def logout
        clear_auth_cookie
        render json: { ok: true }
      end

      def check_if_email_exists
        email  = params[:email].to_s.downcase.strip
        exists = User.exists?(email: email)

        render json: { exists: exists }
      end
    end
  end
end
