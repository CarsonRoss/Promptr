class PromptScoringService
  def self.call(prompt)
    cache_key = ["prompt_score", Digest::SHA256.hexdigest(prompt.to_s), ENV['OPENAI_MODEL'] || 'gpt-4o-mini'].join(':')
    Rails.cache.fetch(cache_key, expires_in: 60.seconds) do
      llm_thread = Thread.new { Scorers::LlmJudgeScorer.evaluate(prompt) }
      empirical_thread = Thread.new { Scorers::EmpiricalScorer.evaluate(prompt) }

      llm = llm_thread.value
      empirical = empirical_thread.value

      avg = (((llm[:score] * 0.6) + (empirical[:score] * 0.4)) / 2.0).round

      # Option A: lower timeout for suggestion to avoid blocking too long
      suggestion = Llm::OpenaiClient.suggest_prompt(prompt, heuristic: nil, llm: llm, empirical: empirical, timeout: 5)

      {
        llm: llm,
        empirical: empirical,
        average: avg,
        suggested_prompt: suggestion['suggested_prompt']
      }
    end
  end
end
