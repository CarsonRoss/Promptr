class Device < ApplicationRecord
  belongs_to :guest_user, optional: true

  validates :device_id, presence: true, uniqueness: true

  # A device is considered paid if it has an associated Stripe customer id
  def paid?
    return false unless stripe_customer_id.present?

    # If the subscription was set to cancel at period end and we've passed that time,
    # consider this device unpaid even if a Stripe customer id remains.
    begin
      cancel_flag = Rails.cache.read(["device", device_id.to_s, "subscription", "cancel_at_period_end"].join(':')).present?
      if cancel_flag
        access_until = Rails.cache.read(["device", device_id.to_s, "subscription", "current_period_end"].join(':'))
        if access_until.present?
          cutoff = Time.parse(access_until).utc rescue nil
          return false if cutoff && Time.current.utc >= cutoff
        end
      end
    rescue => _e
      # if cache/time parsing fails, fall back to customer presence
    end

    true
  end

  def remaining_uses
    # Default trial uses when no guest user record is linked yet
    gu_uses = guest_user&.remaining_uses
    return gu_uses.to_i if gu_uses
    20
  end

  def exhausted?
    !paid? && remaining_uses <= 0
  end

  def consume_trial!
    return remaining_uses if paid?
    guest_user&.decrement_uses!
    remaining_uses
  end

  # Ensure a guest_user exists for this device (for anonymous usage tracking)
  def ensure_guest_user!(initial_uses: 10)
    return guest_user if guest_user.present?
    self.guest_user = GuestUser.find_or_create_by(device_fingerprint: device_id) do |g|
      g.remaining_uses = initial_uses
    end
    save! if changed?
    guest_user
  end
  
  def remaining_uses
    gu_uses = guest_user&.remaining_uses
    return gu_uses.to_i if gu_uses
    10
  end
  
  # Allow force to bypass device-level paid? check
  def consume_trial!(force: false)
    return remaining_uses if paid? && !force
    ensure_guest_user!(initial_uses: 10) if guest_user.nil?
    guest_user.decrement_uses!
    remaining_uses
  end
end


