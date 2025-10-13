require 'rails_helper'

RSpec.describe 'Rack::Attack rate limiting', type: :request do
  before { Rack::Attack.cache.store.clear if Rack::Attack.cache.store.respond_to?(:clear) }
  after  { Rack::Attack.cache.store.clear if Rack::Attack.cache.store.respond_to?(:clear) }
  it 'returns 429 Too Many Requests after threshold is exceeded' do
    allow(Scorers::LlmJudgeScorer).to receive(:evaluate).and_return({ score: 50 })
    allow(Scorers::EmpiricalScorer).to receive(:evaluate).and_return({ score: 50 })

    # Send more than 60 requests quickly; our config is 60 rpm per IP
    65.times do |i|
      post '/api/v1/score', params: { prompt: "p#{i}" }, as: :json
    end
    expect(response.status).to eq(429)
  end
end


