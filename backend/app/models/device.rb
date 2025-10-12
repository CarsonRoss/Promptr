class Device < ApplicationRecord
  validates :device_id, presence: true, uniqueness: true

  scope :paid, -> { where(paid: true) }
  scope :unpaid, -> { where(paid: false) }

  def exhausted?
    !paid && remaining_uses.to_i <= 0
  end

  def consume_trial!
    return remaining_uses if paid
    new_value = [remaining_uses.to_i - 1, 0].max
    update!(remaining_uses: new_value)
    new_value
  end
end


