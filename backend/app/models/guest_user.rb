class GuestUser < ApplicationRecord
    has_many :devices

    validates :device_fingerprint, presence: true, uniqueness: true
    validates :remaining_uses, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    def decrement_uses!
        update!(remaining_uses: [remaining_uses.to_i - 1, 0].max)
    end
end


