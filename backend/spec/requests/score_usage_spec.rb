require 'rails_helper'

RSpec.describe 'Score usage gating', type: :request do
  let(:path) { '/api/v1/score' }
  let(:device_id) { 'dev-usage-test-1' }

  def headers
    { 'CONTENT_TYPE' => 'application/json', 'X-Device-Id' => device_id }
  end

  it 'blocks scoring with 402 when remaining uses == 0' do
    guest = GuestUser.create!(device_fingerprint: device_id, remaining_uses: 0)
    Device.create!(device_id: device_id, guest_user: guest)

    post path, params: { prompt: 'test prompt' }.to_json, headers: headers
    expect(response).to have_http_status(:payment_required)
    body = JSON.parse(response.body)
    expect(body['paywall']).to eq(true)
    expect(body['remaining_uses']).to eq(0)
  end

  it 'blocks cached duplicate scoring when remaining uses == 0' do
    guest = GuestUser.create!(device_fingerprint: device_id, remaining_uses: 0)
    Device.create!(device_id: device_id, guest_user: guest)
    prompt = 'same prompt'

    # Seed cache to simulate prior successful result
    Rails.cache.write(["device:last_prompt", device_id].join(':'), prompt)
    Rails.cache.write(["device:last_result", device_id].join(':'), { ok: true })

    post path, params: { prompt: prompt }.to_json, headers: headers
    expect(response).to have_http_status(:payment_required)
    body = JSON.parse(response.body)
    expect(body['paywall']).to eq(true)
    expect(body['remaining_uses']).to eq(0)
  end

  it 'allows scoring when remaining uses > 0 and decrements after' do
    # Set up with 1 remaining use
    guest = GuestUser.create!(device_fingerprint: device_id, remaining_uses: 1)
    Device.create!(device_id: device_id, guest_user: guest)

    # Stub scoring service to avoid external calls
    allow(PromptScoringService).to receive(:call).and_return({ llm: { score: 10 }, empirical: { score: 10 }, average: 10 })

    post path, params: { prompt: 'unique' }.to_json, headers: headers
    expect(response).to have_http_status(:ok)

    # Next call should be blocked since it should have decremented to 0
    post path, params: { prompt: 'another' }.to_json, headers: headers
    expect(response).to have_http_status(:payment_required)
  end
end


