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
            out = Llm::OpenaiClient.run_prompt(text, temperature: 0.2, timeout: 8, max_retries: 1, max_tokens: 300)
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
        reasons.concat(format_msgs.map { |m| "Output formatting: #{m}." })
      elsif format_points == 0
        if fmt_ctx[:want_json]
          reasons << 'JSON was requested, but the outputs were not valid JSON.'
        elsif fmt_ctx[:want_list]
          reasons << 'A list format was requested, but list markers/structure were not detected in the outputs.'
        else
          reasons << 'The prompt does not request a concrete output format (e.g., JSON keys or an explicit list), so empirical consistency is limited.'
        end
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
      want_json = prompt.downcase.include?('json')
      want_list = prompt.downcase.match?(/\b(list|bullets?)\b/)

      points = 0
      messages = []
      json_ok = 0
      list_detected = 0
      outputs.each do |out|
        next unless out
        if want_json
          begin
            JSON.parse(out)
            points += 20
            messages << 'JSON output valid'
            json_ok += 1
          rescue JSON::ParserError
          end
        end
        if want_list
          if out.include?("\n-") || out.include?("\n*") || out.strip.start_with?('- ')
            points += 10
            messages << 'List format detected'
            list_detected += 1
          end
          if out.lines.size >= 5
            points += 10
            messages << 'List length adequate'
          end
        end
      end
      ctx = { want_json: want_json, want_list: want_list, json_ok: json_ok, list_detected: list_detected }
      [[points, 40].min, messages, ctx]
    end
    private_class_method :format_score

    def self.consistency_score(outputs)
      return [1.0, 0] if outputs.length < 2
      a, b = outputs[0].to_s, outputs[1].to_s
      return [0.0, 40] if a == b && a.length > 0
      distance = normalized_edit_distance(a, b)
      variance = distance
      points = ((1.0 - distance) * 40.0)
      [variance, points.round.clamp(0, 40)]
    end
    private_class_method :consistency_score

    def self.quality_score(outputs)
      out = outputs.first.to_s
      return 0 if out.strip.empty?
      return 0 if HEDGED_PATTERNS.any? { |r| out.match?(r) }
      pts = 10
      pts += 5 if out.length >= 100
      pts += 5 if out =~ /\d/ # presence of actionable items often has numbers
      pts.clamp(0, 20)
    end
    private_class_method :quality_score

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


