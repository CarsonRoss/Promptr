require 'rails_helper'

RSpec.describe Scorers::EmpiricalScorer do
  describe '.evaluate' do
    it 'invokes OpenAI run_prompt and returns a result hash' do
      allow(Llm::OpenaiClient).to receive(:run_prompt).and_return('ok')
      result = described_class.evaluate('Hello')
      expect(result).to include(:score, :reasons, :details)
      expect(Llm::OpenaiClient).to have_received(:run_prompt).at_least(:once)
    end
  end
end


