require 'rails_helper'

RSpec.describe 'Anonymous upgrade flow via signup then checkout', type: :request do
  let(:device_id) { 'dev-upgrade-flow-1' }
  let(:headers)   { { 'CONTENT_TYPE' => 'application/json', 'X-Device-Id' => device_id } }
  let(:email)     { 'new_user@example.com' }
  let(:password)  { 'password123' }
  let(:code)      { '123456' }

  it 'creates account via code verification then returns Stripe checkout URL' do
    # Seed the email verification code that AuthController expects
    Rails.cache.write(["email:verify_code", email].join(':'), code, expires_in: 10.minutes)

    # Verify email endpoint creates the user and sets cookie auth
    post '/api/v1/auth/verify_email', params: { email: email, code: code, password: password, password_confirmation: password }.to_json, headers: headers
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['verified']).to eq(true)
    # Cookie should be set for subsequent authenticated calls
    expect(response.headers['Set-Cookie']).to include('ctx_token')

    # Now calling checkout should produce a Stripe checkout URL for the authenticated unpaid user
    allow(Stripe::Checkout::Session).to receive(:create).and_return(
      double(url: 'https://checkout.stripe.com/test', id: 'cs_test_abc', customer: 'cus_123')
    )

    post '/api/v1/payments/checkout', params: { device_id: device_id }.to_json, headers: headers
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['url']).to eq('https://checkout.stripe.com/test')
  end
end


