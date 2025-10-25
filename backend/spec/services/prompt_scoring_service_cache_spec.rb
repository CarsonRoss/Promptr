require 'rails_helper'

RSpec.describe PromptScoringService do
  describe '.call' do
    it 'invokes both scorers and returns a hash' do
      allow(Scorers::LlmJudgeScorer).to receive(:evaluate).and_return({ score: 80, reasons: [] })
      allow(Scorers::EmpiricalScorer).to receive(:evaluate).and_return({ score: 60, reasons: [] })
      res = described_class.call('prompt')
      expect(Scorers::LlmJudgeScorer).to have_received(:evaluate)
      expect(Scorers::EmpiricalScorer).to have_received(:evaluate)
      expect(res).to include(:llm, :empirical, :average)
    end
  end
end


