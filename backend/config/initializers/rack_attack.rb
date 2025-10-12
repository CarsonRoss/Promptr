require 'redis'
class Rack::Attack
  # Configure cache store for throttling counters
  if Rails.env.test?
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
  elsif ENV['REDIS_URL']
    Rack::Attack.cache.store = Rack::Attack::StoreProxy::RedisStoreProxy.new(Redis.new(url: ENV['REDIS_URL']))
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


