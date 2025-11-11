class ApplicationController < ActionController::API
  include ActionController::Cookies

  private

  def set_auth_cookie(token, expires_at: nil)
    cookies[:ctx_token] = {
      value: token,
      httponly: true,
      secure: Rails.env.production?,
      same_site: Rails.env.production? ? :none : :lax,
      path: '/',
      expires: expires_at
    }
  end

  def clear_auth_cookie
    # Ensure deletion matches the attributes used when setting the cookie.
    # Some browsers require SameSite/Secure alignment for cross-site cookies to be cleared.
    cookies.delete(
      :ctx_token,
      path: '/',
      secure: Rails.env.production?,
      same_site: Rails.env.production? ? :none : :lax
    )
  end

  def current_user_from_cookie
    token = cookies[:ctx_token].to_s
    return nil if token.blank?
    claims = AuthService.decode_jwt(token)
    return nil unless claims
    User.find_by(id: claims[:sub])
  rescue StandardError
    nil
  end
end
