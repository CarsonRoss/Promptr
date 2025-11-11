class User < ApplicationRecord
    self.table_name = 'users_tables'

    after_destroy :clear_cache
    after_initialize :set_default_remaining_uses, if: :new_record?

    has_secure_password

    STATUSES = %w[paid unpaid]

    validates :email, presence: true, uniqueness: true
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :password, length: { minimum: 8 }, allow_nil: true

    scope :paid, -> { where(status: 'paid') }
    scope :unpaid, -> { where(status: 'unpaid') }

    def active_subscription?
        status == 'paid'
    end

    def generate_verification_token(expires_in: 2.days)
        token = SecureRandom.hex(16)
        Rails.cache.write(["user:verify_token", token].join(':'), id, expires_in: expires_in)
        token
    end

    def verify_email_timestamp!
        update!(verified_at: Time.current)
    end

    def paid?
        status == 'paid'
    end

    def remaining_uses_value
        (remaining_uses.nil? ? 10 : remaining_uses.to_i)
    end

    def consume_trial!
        return remaining_uses_value if paid?
        new_val = [remaining_uses_value - 1, 0].max
        update!(remaining_uses: new_val)
        new_val
    end

    def clear_cache
        Rails.cache.delete(["user", id.to_s, "subscription", "cancel_at_period_end"].join(':'))
        Rails.cache.delete(["user", id.to_s, "subscription", "current_period_end"].join(':'))
        Rails.cache.delete(["user", id.to_s, "stripe_customer_id"].join(':'))
    end

    private

    def set_default_remaining_uses
        self.remaining_uses = 10 if remaining_uses.nil?
    end
end