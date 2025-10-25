require 'rails_helper'

RSpec.describe Scorers::LlmJudgeScorer do
  describe '.evaluate' do
    it 'delegates to the OpenAI client and returns a structured hash' do
      allow(Llm::OpenaiClient).to receive(:judge_prompt).and_return({ 'score' => 50, 'reasons' => ['ok'] })
      res = described_class.evaluate('prompt')
      expect(Llm::OpenaiClient).to have_received(:judge_prompt)
      expect(res).to include(:score, :reasons)
    end
  end
end


