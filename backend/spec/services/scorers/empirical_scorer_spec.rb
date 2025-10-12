require 'rails_helper'

RSpec.describe Scorers::EmpiricalScorer do
  describe '.evaluate' do
    let(:prompt_list) { 'List 5 steps to deploy Rails app' }
    let(:prompt_json) { 'Return JSON with keys: steps, risks' }

    it 'returns a hash with score, reasons, and details' do
      allow(Llm::OpenaiClient).to receive(:run_prompt).and_return('ok')
      result = described_class.evaluate('Hello')
      expect(result).to include(:score, :reasons, :details)
      expect(result[:score]).to be_between(0, 100)
    end

    it 'rewards format adherence for lists' do
      allow(Llm::OpenaiClient).to receive(:run_prompt).and_return("- step 1\n- step 2\n- step 3\n- step 4\n- step 5")
      result = described_class.evaluate(prompt_list)
      expect(result[:score]).to be >= 60
      expect(result[:reasons].join(' ')).to match(/format/i)
    end

    it 'rewards JSON parseable output when JSON is requested' do
      allow(Llm::OpenaiClient).to receive(:run_prompt).and_return('{"steps":["a","b"],"risks":["x"]}')
      result = described_class.evaluate(prompt_json)
      expect(result[:score]).to be >= 60
      expect(result[:reasons].join(' ')).to match(/json/i)
    end

    it 'penalizes empty or boilerplate outputs' do
      allow(Llm::OpenaiClient).to receive(:run_prompt).and_return('As an AI language model, I cannot...')
      result = described_class.evaluate('Do something specific')
      expect(result[:score]).to be <= 40
    end

    it 'scores higher when responses are consistent across runs' do
      allow(Llm::OpenaiClient).to receive(:run_prompt).and_return('A', 'A')
      consistent = described_class.evaluate('Say A twice')
      allow(Llm::OpenaiClient).to receive(:run_prompt).and_return('A', 'B')
      inconsistent = described_class.evaluate('Say something')
      expect(consistent[:score]).to be > inconsistent[:score]
      expect(consistent[:details][:variance]).to be <= inconsistent[:details][:variance]
    end
  end
end


