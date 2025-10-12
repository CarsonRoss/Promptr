require 'rails_helper'

RSpec.describe Llm::OpenaiClient do
  describe '.judge_prompt' do
    let(:prompt) { 'Rate this prompt' }

    it 'parses JSON content when model returns a JSON string' do
      fake = {
        'choices' => [
          { 'message' => { 'content' => '{"score":85,"reasons":["clear"]}' } }
        ]
      }
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(double(body: JSON.dump(fake)))
      result = described_class.judge_prompt(prompt)
      expect(result['score']).to eq(85)
      expect(result['reasons']).to include('clear')
    end

    it 'falls back to safe response when invalid JSON is returned' do
      fake = {
        'choices' => [
          { 'message' => { 'content' => 'not json' } }
        ]
      }
      allow_any_instance_of(Net::HTTP).to receive(:request).and_return(double(body: JSON.dump(fake)))
      result = described_class.judge_prompt(prompt)
      expect(result['score']).to eq(0)
      expect(result['reasons'].join(' ')).to match(/invalid/i)
    end

    it 'retries on transient errors and returns fallback after max attempts' do
      allow_any_instance_of(Net::HTTP).to receive(:request).and_raise(Timeout::Error)
      result = described_class.judge_prompt(prompt)
      expect(result['score']).to eq(0)
      expect(result['reasons'].join(' ')).to match(/unavailable|timeout|error/i)
    end
  end

  describe '.suggest_prompt' do
    it 'builds a system prompt that asks to satisfy all three judges' do
      captured_body = nil
      fake = {
        'choices' => [
          { 'message' => { 'content' => '{"suggested_prompt":"X"}' } }
        ]
      }
      expect_any_instance_of(Net::HTTP)).to receive(:request) do |_, req|
        captured_body = req.body
        double(code: '200', body: JSON.dump(fake))
      end

      described_class.suggest_prompt(
        'orig',
        heuristic: { score: 10, reasons: ['too vague'] },
        llm: { score: 20, reasons: ['add specifics'] },
        empirical: { score: 5, reasons: ['return JSON'] }
      )

      payload = JSON.parse(captured_body)
      system_text = payload.dig('messages', 0, 'content').to_s.downcase
      expect(system_text).to include('get what the llm judge is looking for')
      expect(system_text).to include('get what the empirical judge is looking for')
      expect(system_text).to include('get what the heuristic judge is looking for')
      expect(system_text).to match(/satisf(y|ies) .*three judges/)
      # Still enforces json-only output
      expect(system_text).to include('only json')
    end
  end
end


