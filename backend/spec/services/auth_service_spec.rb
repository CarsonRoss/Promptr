require 'rails_helper'

RSpec.describe AuthService do
  let(:user) { User.create!(email: 'user@example.com', password: 'password123', password_confirmation: 'password123', status: 'unpaid') }

  it 'generates and decodes JWT with subject user id' do
    token = described_class.generate_jwt(user_id: user.id, expires_in: 60)
    expect(token).to be_a(String)
    payload = described_class.decode_jwt(token)
    expect(payload).to be_present
    expect(payload[:sub]).to eq(user.id)
  end

  it 'returns nil for expired tokens' do
    token = described_class.generate_jwt(user_id: user.id, expires_in: -1)
    expect(described_class.decode_jwt(token)).to be_nil
  end

  it 'verifies password using has_secure_password' do
    expect(described_class.verify_password(user, 'password123')).to be(true)
    expect(described_class.verify_password(user, 'wrong')).to be(false)
  end
end


