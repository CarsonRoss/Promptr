require 'rails_helper'

RSpec.describe Scorers::HeuristicScorer do
  describe '.evaluate' do
    def eval_score(prompt)
      described_class.evaluate(prompt)
    end

    it 'returns a hash with score, reasons, and issues' do
      result = eval_score('Explain quicksort in 3 steps with pseudocode and complexity.')
      expect(result).to include(:score, :reasons, :issues)
      expect(result[:score]).to be_between(0, 100)
      expect(result[:reasons]).to be_a(Array)
      expect(result[:issues]).to be_a(Array)
    end

    it 'penalizes very short prompts and flags low word count' do
      short = eval_score('Help me')
      longer = eval_score('Explain bubble sort with steps, complexity O(n^2), and example list.')
      expect(short[:score]).to be < longer[:score]
      expect(short[:issues].join(' ')).to match(/Low word count/i)
    end

    it 'flags vague terms and reduces score' do
      vague = eval_score('Write a good thing that is better somehow about stuff')
      clear = eval_score('Write a concise 5-bullet summary of the causes of WW1; include dates.')
      expect(vague[:score]).to be < clear[:score]
      expect(vague[:issues].join(' ')).to match(/Vague terms/i)
    end

    it 'rewards specificity signals (numbers, roles, formats)' do
      base = eval_score('Summarize climate change impacts.')
      specific = eval_score('As a data analyst, summarize climate change impacts in 7 bullet points with sources in JSON.')
      expect(specific[:score]).to be > base[:score]
    end

    it 'rewards well-formed questions or directives' do
      statement = eval_score('List the steps to deploy a Rails app')
      question  = eval_score('Can you list the steps to deploy a Rails app?')
      expect(question[:score]).to be >= statement[:score]
    end

    it 'clamps score between 0 and 100' do
      very_bad = eval_score('thing thing thing')
      very_good = eval_score('As a senior engineer, produce a 10-step checklist to harden a Rails API; include code blocks, commands, and a JSON summary with keys steps, risks, and time_estimate.')
      expect(very_bad[:score]).to be_between(0, 100)
      expect(very_good[:score]).to be_between(0, 100)
    end
  end
end


