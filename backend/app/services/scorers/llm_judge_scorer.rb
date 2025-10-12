module Scorers
  class LlmJudgeScorer
    def self.evaluate(prompt)
      raw = Llm::OpenaiClient.judge_prompt(prompt)
      score = raw.is_a?(Hash) ? raw['score'] : 0
      reasons = raw.is_a?(Hash) ? Array(raw['reasons']) : ['invalid response']
      score = [[score.to_i, 0].max, 100].min
      result = { score: score, reasons: reasons }
      # Surface raw content for downstream insights if available
      if raw.is_a?(Hash) && raw['raw']
        result[:raw] = raw['raw'].to_s
      end
      result
    rescue => e
      { score: 0, reasons: ["judge error: #{e.message}"] }
    end
  end
end


