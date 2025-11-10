require 'redis'
class Rack::Attack
  # Use Rails.cache so Rack::Attack goes through ActiveSupport::Cache::RedisCacheStore in prod,
  # and memory in other envs per your production.rb/development.rb configs.
  Rack::Attack.cache.store = Rails.cache

  # In tests, force an in-memory store to avoid external dependencies.
  if Rails.env.test?
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  end

  # Throttle requests to 60 rpm per IP for API endpoints
  throttle('req/ip', limit: 60, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/api')
  end

  # Safelist localhost only in development
  if Rails.env.development?
    safelist('allow-localhost') do |req|
      ['127.0.0.1', '::1'].include?(req.ip)
    end
  end
end
