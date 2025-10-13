module Scorers
  class EmpiricalScorer
    HEDGED_PATTERNS = [/as an ai language model/i, /cannot assist with/i, /i cannot/i].freeze

    def self.evaluate(prompt, runs: 2)
      text = prompt.to_s
      Rails.logger.info("[EmpiricalScorer] START runs=#{runs} text_len=#{text.length}") if defined?(Rails)
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC) rescue Time.now.to_f
      # Run calls in parallel to cap total latency
      threads = []
      outputs = Array.new(runs)
      runs.times do |i|
        threads << Thread.new do
          ti = Process.clock_gettime(Process::CLOCK_MONOTONIC) rescue Time.now.to_f
          begin
            out = Llm::OpenaiClient.run_prompt(text, temperature: 0.2, timeout: 30, max_retries: 1, max_tokens: 16384)
            outputs[i] = out
          ensure
            ei = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) rescue Time.now.to_f) - ti) * 1000.0
            Rails.logger.info("[EmpiricalScorer] run##{i+1} output_len=#{outputs[i].to_s.length} elapsed=#{ei.round}ms") if defined?(Rails)
          end
        end
      end
      threads.each(&:join)
      Rails.logger.info("[EmpiricalScorer] outputs sizes=#{outputs.map { |o| o.to_s.length }}") if defined?(Rails)

      reasons = []
      details = {}
      score = 0

      # 1) Expected format adherence (0..40)
      format_points, format_msgs, fmt_ctx = format_score(text, outputs)
      Rails.logger.info("[EmpiricalScorer] format_points=#{format_points} msgs=#{format_msgs}") if defined?(Rails)
      score += format_points
      if format_msgs.any?
        reasons.concat(format_msgs.map { |m| "Output structure: #{m}." })
      elsif format_points == 0
        reasons << 'The outputs lack clear structure. Consider requesting a specific format (JSON, list, code, etc.) or asking for organized sections.'
      end

      # 2) Consistency across runs (0..40)
      variance, consistency_points = consistency_score(outputs)
      Rails.logger.info("[EmpiricalScorer] variance=#{variance} consistency_points=#{consistency_points}") if defined?(Rails)
      details[:variance] = variance
      score += consistency_points
      if outputs.length >= 2
        if consistency_points >= 30
          reasons << 'The model produced similar outputs across runs, indicating a stable prompt.'
        else
          reasons << 'Outputs varied significantly between runs; tighten instructions and format requirements to increase consistency.'
        end
      end

      # 3) Basic quality heuristics (0..20)
      quality_points = quality_score(outputs)
      Rails.logger.info("[EmpiricalScorer] quality_points=#{quality_points}") if defined?(Rails)
      score += quality_points
      if quality_points >= 15
        reasons << 'The response appears substantive and actionable.'
      else
        reasons << 'The response seems brief or generic; ask for concrete steps, numbers, or examples.'
      end

      score = [[score.round, 0].max, 100].min
      total = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) rescue Time.now.to_f) - t0) * 1000.0
      Rails.logger.info("[EmpiricalScorer] final_score=#{score} total_elapsed=#{total.round}ms") if defined?(Rails)
      { score: score, reasons: reasons, details: details }
    rescue => e
      { score: 0, reasons: ["empirical error: #{e.message}"], details: { variance: 1.0 } }
    end

    def self.format_score(prompt, outputs)
      points = 0
      messages = []
      
      # Instead of checking if JSON/list was requested, check if outputs are well-structured
      outputs.each do |out|
        next unless out
        output_text = out.to_s.strip
        next if output_text.empty?
        
        structure_points = 0
        
        # 1. Check for structured content (any format)
        has_structure = false
        
        # JSON structure
        if output_text.match?(/\{[\s\S]*\}/) && output_text.match?(/"[\w_]+"\s*:/)
          structure_points += 10
          messages << 'Structured JSON-like output detected' unless messages.include?('Structured JSON-like output detected')
          has_structure = true
        end
        
        # Code structure (functions, classes, methods)
        if output_text.match?(/\b(def|function|class|const|let|var)\s+\w+/i)
          structure_points += 10
          messages << 'Code structure detected' unless messages.include?('Code structure detected')
          has_structure = true
        end
        
        # List structure (bullets, numbered, etc.)
        if output_text.match?(/(?:^|\n)\s*[-*•]\s+\w+/) || output_text.match?(/(?:^|\n)\s*\d+\.\s+\w+/)
          structure_points += 8
          messages << 'List structure detected' unless messages.include?('List structure detected')
          has_structure = true
        end
        
        # Table/columnar structure
        if output_text.match?(/\|.*\|/) && output_text.scan(/\|/).count >= 4
          structure_points += 8
          messages << 'Table structure detected' unless messages.include?('Table structure detected')
          has_structure = true
        end
        
        # 2. Check for organization (paragraphs, sections, etc.)
        if output_text.lines.count >= 3
          structure_points += 5
        end
        
        # 3. If no clear structure, check if it's a coherent response
        if !has_structure && output_text.length >= 50
          structure_points += 5
          messages << 'Coherent text response' unless messages.include?('Coherent text response')
        end
        
        points += [structure_points, 20].min
      end
      
      ctx = { has_structure: points > 0 }
      [[points, 40].min, messages, ctx]
    end
    private_class_method :format_score

    # Add this new method before format_score
    def self.detect_json_request(prompt)
      text = prompt.downcase
      # Direct JSON mentions
      return true if text.include?('json')
      
      # Format requests
      return true if text.match?(/\b(format|return|output|provide)\s+(as\s+)?json\b/)
      return true if text.match?(/\bjson\s+(format|object|response|output)\b/)
      
      # Structure requests that imply JSON
      return true if text.include?('keys') && text.include?('{')
      return true if text.match?(/\bkeys?\s*[:=]\s*\[/)
      
      false
    end
    private_class_method :detect_json_request

    def self.extract_json_from_text(text)
      return nil if text.to_s.strip.empty?
      s = text.dup
      # Strip ```json fences if present
      if s =~ /```json([\s\S]*?)```/i
        return $1.strip
      end
      # Fallback: grab the first {...} balanced region
      start = s.index('{')
      return nil unless start
      # naive scan to last '}'
      last = s.rindex('}')
      return nil unless last && last > start
      candidate = s[start..last]
      candidate
    end
    private_class_method :extract_json_from_text

    def self.consistency_score(outputs)
      return [1.0, 0] if outputs.length < 2
      a, b = outputs[0].to_s, outputs[1].to_s
      return [0.0, 40] if a == b && a.length > 0
      
      distance = normalized_edit_distance(a, b)
      variance = distance
      
      if distance <= 0.2
        # Very similar (80%+) → full points
        points = 40
      elsif distance <= 0.4
        # Moderately similar (60-80%) → 30-40 points
        # Linear interpolation: 40 - ((distance - 0.2) / 0.2) * 10
        points = 40 - ((distance - 0.2) / 0.2) * 10
      elsif distance <= 0.6
        # Somewhat similar (40-60%) → 20-30 points
        # Linear interpolation: 30 - ((distance - 0.4) / 0.2) * 10
        points = 30 - ((distance - 0.4) / 0.2) * 10
      elsif distance <= 0.8
        # Slightly similar (20-40%) → 10-20 points
        # Linear interpolation: 20 - ((distance - 0.6) / 0.2) * 10
        points = 20 - ((distance - 0.6) / 0.2) * 10
      else
        # Very different (0-20%) → 0-10 points
        points = [10 - ((distance - 0.8) / 0.2) * 10, 0].max
      end
      
      [variance, points.round.clamp(0, 40)]
    end
    private_class_method :consistency_score

    def self.quality_score(outputs)
      return 0 if outputs.empty?
      
      total_points = 0
      valid_outputs = 0
      
      outputs.each do |out|
        output_text = out.to_s
        next if output_text.strip.empty?
        
        # Skip hedged responses
        next if HEDGED_PATTERNS.any? { |r| output_text.match?(r) }
        
        # More reasonable quality thresholds
        pts = 0
        
        # Length-based scoring (more granular)
        if output_text.length >= 200
          pts += 10  # Substantial response
        elsif output_text.length >= 100
          pts += 8   # Good response
        elsif output_text.length >= 50
          pts += 5   # Adequate response
        elsif output_text.length >= 20
          pts += 3   # Minimal response
        else
          pts += 1   # Very short response
        end
        
        # Content quality bonuses
        pts += 3 if output_text =~ /\d/  # Contains numbers
        pts += 2 if output_text.match?(/\b(step|process|method|way|how|what|why|when|where)\b/i)  # Actionable content
        pts += 2 if output_text.match?(/\b(first|second|third|next|then|finally|also|additionally)\b/i)  # Structured content
        
        total_points += pts
        valid_outputs += 1
      end
      
      return 0 if valid_outputs == 0
      (total_points.to_f / valid_outputs).round.clamp(0, 20)
    end

    def self.normalized_edit_distance(a, b)
      return 0.0 if a == b
      return 1.0 if a.empty? || b.empty?
      dist = levenshtein(a, b)
      dist.to_f / [a.length, b.length].max
    end
    private_class_method :normalized_edit_distance

    def self.levenshtein(a, b)
      m = a.length
      n = b.length
      d = Array.new(m + 1) { Array.new(n + 1) }
      (0..m).each { |i| d[i][0] = i }
      (0..n).each { |j| d[0][j] = j }
      (1..m).each do |i|
        (1..n).each do |j|
          cost = a[i - 1] == b[j - 1] ? 0 : 1
          d[i][j] = [
            d[i - 1][j] + 1,
            d[i][j - 1] + 1,
            d[i - 1][j - 1] + cost
          ].min
        end
      end
      d[m][n]
    end
    private_class_method :levenshtein
  end
end


