class User < ApplicationRecord
    self.table_name = 'users_tables'

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
end