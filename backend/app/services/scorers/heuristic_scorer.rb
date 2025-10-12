module Scorers
  class HeuristicScorer
    VAGUE_TERMS = %w[thing stuff good better nice some etc].freeze
    FORMAT_KEYWORDS = %w[json list bullet bullets steps table code markdown].freeze
    ROLE_KEYWORDS = %w[as as_a as-an as-an].freeze

    def self.evaluate(prompt)
      text = (prompt || '').to_s.strip
      words = text.split(/\s+/)
      word_count = words.length

      issues = []
      reasons = []

      score = 0
      # 1) Word count (0..40 pts)
      wc_points = word_count_points(word_count)
      score += wc_points
      issues << 'Low word count' if word_count < 10
      if word_count < 10
        reasons << 'The prompt is very short; add concrete details, examples, and constraints so the model has enough context.'
      elsif word_count.between?(15, 80)
        reasons << 'The prompt length is appropriate for clarity.'
      elsif word_count > 120
        reasons << 'The prompt is quite long; trimming to the essential goal and constraints would improve focus.'
      else
        reasons << 'The prompt length is reasonable.'
      end

      # 2) Vague terms penalty (up to -25)
      vague_hits = words.map { |w| w.downcase.gsub(/[^a-z]/, '') } & VAGUE_TERMS
      if vague_hits.any?
        penalty = [vague_hits.size * 5, 25].min
        score -= penalty
        issues << "Vague terms: #{vague_hits.uniq.join(', ')}"
        reasons << "Avoid vague terms like #{vague_hits.uniq.join(', ')}; replace with specific nouns and actions."
      end

      # 3) Specificity signals (0..20)
      specificity = 0
      specificity += 8 if text =~ /\b\d+\b/ # presence of numbers
      # If JSON is requested with explicit keys, reward more strongly
      if text.downcase.include?('json') && text =~ /\bkeys?\b|\bfields?\b|\bproperties\b/i
        specificity += 10
      elsif FORMAT_KEYWORDS.any? { |k| text.downcase.include?(k) }
        specificity += 6
      end
      specificity += 6 if text.downcase.include?('role:') || text.downcase.start_with?('as ')
      specificity = [specificity, 20].min
      score += specificity
      spec_msgs = []
      spec_msgs << 'including concrete numbers' if text =~ /\b\d+\b/
      spec_msgs << 'requesting a specific format' if FORMAT_KEYWORDS.any? { |k| text.downcase.include?(k) }
      spec_msgs << 'setting a clear role for the assistant' if text.downcase.include?('role:') || text.downcase.start_with?('as ')
      if spec_msgs.any?
        reasons << "Good specificity signals (#{spec_msgs.join(', ')})."
      end

      # 4) Well-formedness (0..15)
      well_formed = 0
      well_formed += 8 if text.strip.end_with?('?')
      well_formed += 7 if text =~ /^(please\s+)?(write|list|explain|generate|create|produce|summarize|design)\b/i
      well_formed = [well_formed, 15].min
      score += well_formed
      if text.strip.end_with?('?')
        reasons << 'It is phrased as a clear question.'
      elsif text =~ /^(please\s+)?(write|list|explain|generate|create|produce|summarize|design)\b/i
        reasons << 'It uses a direct action verb, which makes the request unambiguous.'
      else
        reasons << 'Rewriting as a direct request or question would make the intent clearer.'
      end

      # Clamp 0..100
      score = [[score, 0].max, 100].min

      { score: score, reasons: reasons, issues: issues }
    end

    def self.word_count_points(count)
      # Target 15..80 words for full points (40), linear falloff outside
      return 0 if count <= 3
      return 40 if count.between?(15, 80)
      if count < 15
        # scale from 0 at 3 words to 40 at 15 words
        span = 12.0
        gained = ((count - 3) / span) * 40.0
        return gained.clamp(0, 40).round
      end
      # Overly long prompts lose points gradually beyond 120
      return 30 if count.between?(81, 120)
      # 120+ reduces to 20 points
      20
    end
    private_class_method :word_count_points
  end
end


