class PromptScoringService
  def self.call(prompt)
    cache_key = ["prompt_score", Digest::SHA256.hexdigest(prompt.to_s), ENV['OPENAI_MODEL'] || 'gpt-4o-mini'].join(':')
    Rails.cache.fetch(cache_key, expires_in: 60.seconds) do
      llm = Scorers::LlmJudgeScorer.evaluate(prompt)
      empirical = Scorers::EmpiricalScorer.evaluate(prompt)
      avg = ((llm[:score] * 0.6) + (empirical[:score] * 0.4) / 2.0).round
      # Ask LLM to synthesize a better prompt suggestion
      suggestion = Llm::OpenaiClient.suggest_prompt(
        prompt,
        heuristic: nil, # No heuristic judge anymore
        llm: llm,
        empirical: empirical
      )
      {
        llm: llm,
        empirical: empirical,
        average: avg,
        suggested_prompt: suggestion['suggested_prompt']
      }
    end
  end
end


