require 'rails_helper'

RSpec.describe 'Auth verify_email validations', type: :request do
  let(:path) { '/api/v1/auth/verify_email' }

  it 'rejects when password confirmation is missing' do
    email = 'verifyme@example.com'
    code  = '654321'
    Rails.cache.write(["email:verify_code", email].join(':'), code, expires_in: 10.minutes)

    post path, params: {
      email: email,
      code: code,
      password: 'password123'
    }.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }

    expect(response).to have_http_status(:unprocessable_entity)
    body = JSON.parse(response.body)
    expect(body['error']).to eq('password_confirmation_mismatch')
  end
end


