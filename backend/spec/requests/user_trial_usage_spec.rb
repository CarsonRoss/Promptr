require 'rails_helper'

RSpec.describe 'User remaining uses', type: :request do
  let(:path) { '/api/v1/score' }
  let(:device_id) { 'dev-user-uses' }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json', 'X-Device-Id' => device_id } }

  before do
    allow(PromptScoringService).to receive(:call).and_return({ llm: { score: 10 }, empirical: { score: 10 }, average: 10 })
  end

  it 'defaults to 10 remaining uses for new unpaid users and decrements on score' do
    user = User.create!(email: 'trial@example.com', password: 'password123', password_confirmation: 'password123', status: 'unpaid')
    expect(user.remaining_uses_value).to eq(10)

    # Authenticate this user via cookie stub
    allow_any_instance_of(ApplicationController).to receive(:current_user_from_cookie).and_return(user)

    post path, params: { prompt: 'first' }.to_json, headers: headers
    expect(response).to have_http_status(:ok)

    expect(user.reload.remaining_uses_value).to eq(9)
  end

  it 'inherits device remaining uses on verify_email when creating a new user' do
    # Device has 5 remaining uses
    guest = GuestUser.create!(device_fingerprint: device_id, remaining_uses: 5)
    Device.create!(device_id: device_id, guest_user: guest)

    email = 'inherit@example.com'
    code  = '123456'
    # Prime cache for verification code path
    Rails.cache.write(["email:verify_code", email].join(':'), code, expires_in: 10.minutes)

    # Call verify_email with header so controller can copy device uses
    post "/api/v1/auth/verify_email",
      params: { email: email, code: code, password: 'password123', password_confirmation: 'password123' }.to_json,
      headers: headers
    expect(response).to have_http_status(:ok)
    u = User.find_by(email: email)
    expect(u).to be_present
    expect(u.remaining_uses_value).to eq(5)
  end
end


