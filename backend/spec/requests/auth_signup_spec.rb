require 'rails_helper'

RSpec.describe 'Auth signup validations', type: :request do
  let(:path) { '/api/v1/auth/signup' }

  before do
    allow(EmailVerificationService).to receive(:send_code_to_email).and_return(true)
  end

  it 'rejects when password confirmation is missing' do
    post path, params: {
      email: 'new@example.com',
      password: 'password123'
    }.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rejects when password and confirmation do not match' do
    post path, params: {
      email: 'new@example.com',
      password: 'password123',
      password_confirmation: 'different'
    }.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'accepts when password and confirmation match' do
    post path, params: {
      email: 'new@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    }.to_json, headers: { 'CONTENT_TYPE' => 'application/json' }
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['created']).to eq(true)
  end
end


