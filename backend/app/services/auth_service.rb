require 'jwt'
require 'active_support/core_ext/hash/indifferent_access'

class AuthService
  DEFAULT_ALGORITHM = 'HS256'.freeze

  def self.jwt_secret
    env_secret = ENV['JWT_SECRET']
    return env_secret if env_secret && !env_secret.empty?
    Rails.application.secret_key_base
  end

  # Generate a signed JWT token for the given user id.
  # extra_claims can include additional fields (e.g., roles).
  def self.generate_jwt(user_id:, extra_claims: {})
    expiry_seconds = (ENV['JWT_EXPIRATION'] || 1209600).to_i # 14 days
    issued_at = Time.now.to_i
    payload = {
      sub: user_id,
      iat: issued_at,
      exp: issued_at + expiry_seconds
    }
    if extra_claims && !extra_claims.empty?
      begin
        payload.merge!(extra_claims.symbolize_keys)
      rescue NoMethodError
        payload.merge!(extra_claims)
      end
    end
    JWT.encode(payload, jwt_secret, DEFAULT_ALGORITHM)
  end

  # Decode and verify a JWT token. Returns a hash with indifferent access or nil when invalid/expired.
  def self.decode_jwt(token)
    decoded, = JWT.decode(token.to_s, jwt_secret, true, { algorithm: DEFAULT_ALGORITHM })
    decoded.with_indifferent_access
  rescue JWT::ExpiredSignature, JWT::DecodeError
    nil
  end

  # Verify a plaintext password against the user's password digest via has_secure_password.
  def self.verify_password(user, plaintext_password)
    return false unless user && plaintext_password.to_s.present?
    !!user.authenticate(plaintext_password)
  end
end


