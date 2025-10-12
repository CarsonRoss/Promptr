require 'rails_helper'

RSpec.describe 'Score API', type: :request do
  describe 'POST /api/v1/score' do
    let(:origin) { 'http://localhost:5173' }
    let(:prompt) { 'Summarize SOLID in 5 bullets and output JSON {bullets:[...]}' }

    before do
      allow(Scorers::HeuristicScorer).to receive(:evaluate).and_return({ score: 70, reasons: ['ok'], issues: [] })
      allow(Scorers::LlmJudgeScorer).to receive(:evaluate).and_return({ score: 80, reasons: ['clear'] })
      allow(Scorers::EmpiricalScorer).to receive(:evaluate).and_return({ score: 60, reasons: ['json valid'], details: { variance: 0.1 } })
      allow(Llm::OpenaiClient).to receive(:suggest_prompt).and_return({ 'suggested_prompt' => 'Improved prompt example' })
    end

    it 'returns heuristic, llm, empirical, and average fields' do
      post '/api/v1/score',
        params: { prompt: prompt },
        as: :json,
        headers: { 'Origin' => origin }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['heuristic']).to include('score')
      expect(json['llm']).to include('score')
      expect(json['empirical']).to include('score')
      expect(json['average']).to eq(((70 + 80 + 60) / 3.0).round)
      expect(json['suggested_prompt']).to eq('Improved prompt example')
    end

    it 'validates prompt presence' do
      post '/api/v1/score', params: { prompt: '' }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json['error']).to match(/prompt/i)
    end
  end
end


