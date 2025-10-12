require 'rails_helper'

RSpec.describe Scorers::LlmJudgeScorer do
  describe '.evaluate' do
    let(:prompt) { 'Summarize the SOLID principles in 5 bullets.' }

    it 'returns a hash with score and reasons from the client' do
      allow(Llm::OpenaiClient).to receive(:judge_prompt).and_return({ 'score' => 84, 'reasons' => ['Clear structure', 'Specific format'] })
      result = described_class.evaluate(prompt)
      expect(result).to include(:score, :reasons)
      expect(result[:score]).to eq(84)
      expect(result[:reasons]).to include('Clear structure')
    end

    it 'clamps score to 0..100 when client returns out-of-range' do
      allow(Llm::OpenaiClient).to receive(:judge_prompt).and_return({ 'score' => 150, 'reasons' => [] })
      result = described_class.evaluate(prompt)
      expect(result[:score]).to eq(100)
    end

    it 'handles malformed client response by returning a safe low score with reason' do
      allow(Llm::OpenaiClient).to receive(:judge_prompt).and_return('not json')
      result = described_class.evaluate(prompt)
      expect(result[:score]).to be_between(0, 100)
      expect(result[:reasons].join(' ')).to match(/invalid/i)
    end

    it 'handles client errors gracefully with fallback response' do
      allow(Llm::OpenaiClient).to receive(:judge_prompt).and_raise(StandardError.new('network error'))
      result = described_class.evaluate(prompt)
      expect(result[:score]).to be_between(0, 100)
      expect(result[:reasons].join(' ')).to match(/unavailable|error/i)
    end

    it 'propagates raw judge response content when provided' do
      raw_json = { 'score' => 72, 'reasons' => ['clear ask'], 'raw' => '{"score":72,"reasons":["clear ask"]}' }
      allow(Llm::OpenaiClient).to receive(:judge_prompt).and_return(raw_json)
      result = described_class.evaluate(prompt)
      expect(result).to include(:raw)
      expect(result[:raw]).to include('"score":72')
    end
  end
end


