class Device < ApplicationRecord
  belongs_to :guest_user, optional: true

  validates :device_id, presence: true, uniqueness: true

  # A device is considered paid if it has an associated Stripe customer id
  def paid?
    stripe_customer_id.present?
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
end


