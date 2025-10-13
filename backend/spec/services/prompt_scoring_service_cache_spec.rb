require 'rails_helper'

RSpec.describe PromptScoringService do
  describe '.call caching' do
    let(:prompt) { 'Explain MVC in 3 bullets' }

    before do
      # Use memory store cache in test for this spec
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
      allow(Scorers::LlmJudgeScorer).to receive(:evaluate).and_return({ score: 80 })
      allow(Scorers::EmpiricalScorer).to receive(:evaluate).and_return({ score: 60 })
    end

    it 'caches results to avoid duplicate scorer calls within TTL' do
      result1 = described_class.call(prompt)
      expect(result1[:average]).to eq(70)

      # Call again with same prompt
      result2 = described_class.call(prompt)
      expect(result2[:average]).to eq(70)

      # Llm/Empirical should have been called only once each
      expect(Scorers::LlmJudgeScorer).to have_received(:evaluate).once
      expect(Scorers::EmpiricalScorer).to have_received(:evaluate).once
    end
  end
end


