require 'rails_helper'

RSpec.describe 'Health', type: :request do
  let(:origin) { 'http://localhost:5173' }

  describe 'GET /api/v1/health' do
    it 'returns 200 with JSON body' do
      get '/api/v1/health', headers: { 'ACCEPT' => 'application/json', 'Origin' => origin }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('ok')
    end
  end

  describe 'CORS preflight OPTIONS /api/v1/health' do
    it 'responds with 204 No Content and proper CORS headers' do
      options '/api/v1/health', headers: {
        'Origin' => origin,
        'Access-Control-Request-Method' => 'GET'
      }
      expect(response.status).to eq(204).or eq(200)
      expect(response.headers['Access-Control-Allow-Origin']).to eq(origin).or eq('*')
      expect(response.headers['Access-Control-Allow-Methods']).to include('GET')
    end
  end
end


