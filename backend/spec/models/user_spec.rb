require 'rails_helper'

RSpec.describe User, type: :model do
  it 'validates email presence and uniqueness' do
    u1 = described_class.create!(email: 'a@example.com', password: 'password123', password_confirmation: 'password123', status: 'unpaid')
    expect(u1).to be_persisted
    expect { described_class.create!(email: 'a@example.com', password: 'password123', password_confirmation: 'password123', status: 'unpaid') }
      .to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'hashes password and authenticates via has_secure_password' do
    u = described_class.create!(email: 'b@example.com', password: 'password123', password_confirmation: 'password123', status: 'unpaid')
    expect(u.password_digest).to be_present
    expect(u.authenticate('password123')).to be_truthy
    expect(u.authenticate('wrong')).to be_falsey
  end

  it 'enforces minimum password length when provided' do
    u = described_class.new(email: 'c@example.com', password: 'short', password_confirmation: 'short', status: 'unpaid')
    expect(u.valid?).to be_falsey
    expect(u.errors[:password]).to be_present
  end

  it 'generates a verification token and verifies email' do
    u = described_class.create!(email: 'd@example.com', password: 'password123', password_confirmation: 'password123', status: 'unpaid')
    token = u.generate_verification_token
    expect(token).to be_a(String)
    expect(token.length).to be > 10

    expect { u.verify_email! }.to change { u.reload.verified_at }.from(nil)
  end

  it 'reports active_subscription? based on status' do
    unpaid = described_class.create!(email: 'e@example.com', password: 'password123', password_confirmation: 'password123', status: 'unpaid')
    paid   = described_class.create!(email: 'f@example.com', password: 'password123', password_confirmation: 'password123', status: 'paid')
    expect(unpaid.active_subscription?).to be(false)
    expect(paid.active_subscription?).to be(true)
  end
end


