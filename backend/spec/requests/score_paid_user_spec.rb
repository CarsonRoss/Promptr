require 'rails_helper'

RSpec.describe 'Score API for paid users', type: :request do
  let(:path) { '/api/v1/score' }
  let(:device_id) { 'dev-paid-allow' }
  let(:headers) { { 'CONTENT_TYPE' => 'application/json', 'X-Device-Id' => device_id } }

  it 'allows scoring for paid users even when device remaining_uses == 0' do
    # Device exhausted
    guest = GuestUser.create!(device_fingerprint: device_id, remaining_uses: 0)
    Device.create!(device_id: device_id, guest_user: guest)
    # Paid user session
    user = User.create!(email: 'paid@example.com', password: 'password123', password_confirmation: 'password123', status: 'paid')
    allow_any_instance_of(ApplicationController).to receive(:current_user_from_cookie).and_return(user)

    allow(PromptScoringService).to receive(:call).and_return({ llm: { score: 10 }, empirical: { score: 10 }, average: 10 })

    post path, params: { prompt: 'should work' }.to_json, headers: headers
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['average']).to eq(10)
  end
end


