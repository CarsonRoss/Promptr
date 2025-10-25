require 'rails_helper'

RSpec.describe 'Auth API', type: :request do
  let(:base_path) { '/api/v1/auth' }

  describe 'POST /signup' do
    it 'creates a user and sends verification email' do
      allow(EmailVerificationService).to receive(:send_verification_email).and_return(true)

      payload = { email: 'new@example.com', password: 'password123', password_confirmation: 'password123' }
      post "#{base_path}/signup", params: payload

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['created']).to eq(true)
      user = User.find_by(email: 'new@example.com')
      expect(user).to be_present
      expect(EmailVerificationService).to have_received(:send_verification_email).with(user)
    end

    it 'returns validation errors for bad input' do
      post "#{base_path}/signup", params: { email: '', password: 'short' }
      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body['error']).to eq('validation_failed')
    end
  end

  describe 'POST /login' do
    let!(:user) do
      User.create!(email: 'login@example.com', password: 'password123', password_confirmation: 'password123', status: 'unpaid')
    end

    it 'returns a JWT for valid credentials' do
      allow(AuthService).to receive(:generate_jwt).and_return('token-abc')
      post "#{base_path}/login", params: { email: 'login@example.com', password: 'password123' }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['token']).to eq('token-abc')
    end

    it 'returns 401 for invalid credentials' do
      post "#{base_path}/login", params: { email: 'login@example.com', password: 'wrong' }
      expect(response).to have_http_status(:unauthorized)
      body = JSON.parse(response.body)
      expect(body['error']).to eq('invalid_credentials')
    end
  end

  describe 'POST /verify_email' do
    let!(:user) do
      User.create!(email: 'verify@example.com', password: 'password123', password_confirmation: 'password123', status: 'unpaid')
    end

    it 'verifies via 6-digit code' do
      Rails.cache.write(["user:verify_code", user.id].join(':'), '123456', expires_in: 15.minutes)
      post "#{base_path}/verify_email", params: { email: 'verify@example.com', code: '123456' }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['verified']).to eq(true)
    end

    it 'verifies via signed token' do
      token = user.generate_verification_token
      post "#{base_path}/verify_email", params: { token: token }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['verified']).to eq(true)
    end

    it 'returns error for invalid token' do
      post "#{base_path}/verify_email", params: { token: 'bad' }
      expect(response.status).to be_between(400, 422).inclusive
      body = JSON.parse(response.body)
      expect(body['error']).to be_present
    end
  end

  describe 'POST /resend_verification' do
    let!(:user) do
      User.create!(email: 'resend@example.com', password: 'password123', password_confirmation: 'password123', status: 'unpaid')
    end

    it 'resends verification email' do
      allow(EmailVerificationService).to receive(:send_verification_email).and_return(true)
      post "#{base_path}/resend_verification", params: { email: 'resend@example.com' }
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['sent']).to eq(true)
    end

    it 'returns not_found for missing user' do
      post "#{base_path}/resend_verification", params: { email: 'missing@example.com' }
      expect(response).to have_http_status(:not_found)
      body = JSON.parse(response.body)
      expect(body['error']).to eq('not_found')
    end
  end
end


