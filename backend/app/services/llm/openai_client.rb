require 'net/http'
require 'json'

module Llm
  class OpenaiClient
    OPENAI_URL = URI('https://api.openai.com/v1/chat/completions')

    def self.judge_prompt(prompt, model: ENV.fetch('OPENAI_MODEL', 'gpt-4o-mini'), timeout: 20, max_retries: 3)
      # Build a strict JSON-only instruction
      system_prompt = <<~PROMPT
        You are a prompt quality evaluator. Rate the user's prompt from 0-100 based on:
        - Clarity: Is the request clear and unambiguous?
        - Completeness: Does it provide necessary details to accomplish what it is asking for?
        - Feasibility: Can this be reasonably accomplished?
        - Specificity: Are requirements well-defined?
        - Rubustness: If the prompt asks for code, look for potential edge cases and errors that the user should consider.
        - Context: Does the prompt use too much context? Not enough context?
        
        Return ONLY valid JSON: {"score": number, "reasons": string[]}
        
        Scoring guidelines:
        - 90-100: Excellent prompt with clear intent, specific requirements, and all necessary context
        - 80-89: Good prompt with minor room for improvement
        - 70-79: Decent prompt but missing some important details
        - 60-69: Acceptable but vague or incomplete
        - Below 60: Significant issues with clarity or completeness
        
        Be fair and reward well-structured prompts. Only deduct points for genuine issues.
        Separate what needs to be added to make the prompt better (if there is anything) by a newline.
      PROMPT

      payload = {
        model: model,
        messages: [
          { role: 'system', content: system_prompt },
          { role: 'user', content: prompt.to_s }
        ],
        temperature: 0.0,
        # Ask the API to emit valid JSON only when supported by the model
        response_format: { type: 'json_object' },
        max_tokens: 200
      }

      http = Net::HTTP.new(OPENAI_URL.host, OPENAI_URL.port)
      http.use_ssl = true
      http.read_timeout = timeout
      http.open_timeout = timeout
      req = Net::HTTP::Post.new(OPENAI_URL.request_uri)
      api_key = ENV['OPENAI_API_KEY']
      req['Authorization'] = "Bearer #{api_key}" if api_key && !api_key.empty?
      req['Content-Type'] = 'application/json'
      req.body = JSON.dump(payload)

      attempts = 0
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC) rescue Time.now.to_f
      Rails.logger.info("[LLM::OpenaiClient] judge_prompt START model=#{model} timeout=#{timeout}s") if defined?(Rails)
      loop do
        attempts += 1
        begin
          res = http.request(req)
          status = res.code.to_i rescue 0
          raw_body = res.body.to_s
          body = JSON.parse(raw_body) rescue {}
          elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) rescue Time.now.to_f) - t0) * 1000.0
          Rails.logger.info("[LLM::OpenaiClient] judge_prompt HTTP #{status} elapsed=#{elapsed.round}ms") if defined?(Rails)
          Rails.logger.debug("[LLM::OpenaiClient] judge_prompt raw body: #{raw_body}") if defined?(Rails)

          # Non-200 -> retry on transient or return error
          if status != 200
            if (status >= 500 || status == 429) && attempts <= max_retries
              sleep(0.4 * (2 ** (attempts - 1)))
              next
            end
            return { 'score' => 0, 'reasons' => ["judge http #{status}"], 'raw' => raw_body }
          end

          # OpenAI error envelope
          if body.is_a?(Hash) && body['error']
            msg = body.dig('error', 'message').to_s
            return { 'score' => 0, 'reasons' => ["judge error: #{msg}"], 'raw' => raw_body }
          end

          content = body.dig('choices', 0, 'message', 'content').to_s
          Rails.logger.info("[LLM::OpenaiClient] judge_prompt raw content: #{content.inspect}") if defined?(Rails)

          begin
            parsed = JSON.parse(content)
            if parsed.is_a?(Hash) && parsed.key?('score')
              parsed['raw'] = content
              return parsed
            end
          rescue JSON::ParserError
            # Attempt to extract a JSON object from fenced or prefixed text
            extracted = extract_json_object(content)
            if extracted
              begin
                parsed2 = JSON.parse(extracted)
                if parsed2.is_a?(Hash) && parsed2.key?('score')
                  parsed2['raw'] = content
                  return parsed2
                end
              rescue JSON::ParserError
                # still invalid; continue
              end
            end
          end

          # If we reached here, content was not valid JSON with score; break and fall through
          break
        rescue Timeout::Error, Errno::ECONNRESET, Errno::ETIMEDOUT => e
          Rails.logger.warn("[LLM::OpenaiClient] judge_prompt retry=#{attempts} due to #{e.class}") if defined?(Rails)
          if attempts <= max_retries
            sleep(0.4 * (2 ** (attempts - 1)))
            next
          end
          return { 'score' => 0, 'reasons' => ["judge unavailable: #{e.class}"] }
        end
      end

      Rails.logger.warn("[LLM::OpenaiClient] judge_prompt invalid json, content: #{content.inspect}") if defined?(Rails)
      { 'score' => 0, 'reasons' => ['invalid json from judge'], 'raw' => content.to_s }
    rescue => e
      Rails.logger.error("[LLM::OpenaiClient] judge_prompt error: #{e.class} #{e.message}") if defined?(Rails)
      { 'score' => 0, 'reasons' => ["judge unavailable: #{e.message}"] }
    end

    # Extract the first plausible JSON object from a string.
    # Handles ```json ... ``` fences and plain text with a JSON object embedded.
    def self.extract_json_object(text)
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

    def self.run_prompt(prompt, model: ENV.fetch('OPENAI_MODEL', 'gpt-4o-mini'), temperature: 0.2, timeout: 10, max_retries: 2, max_tokens: nil)
      payload = {
        model: model,
        messages: [
          { role: 'user', content: prompt.to_s }
        ],
        temperature: temperature
      }
      payload[:max_tokens] = max_tokens if max_tokens

      http = Net::HTTP.new(OPENAI_URL.host, OPENAI_URL.port)
      http.use_ssl = true
      http.read_timeout = timeout
      req = Net::HTTP::Post.new(OPENAI_URL.request_uri)
      api_key = ENV['OPENAI_API_KEY']
      req['Authorization'] = "Bearer #{api_key}" if api_key && !api_key.empty?
      req['Content-Type'] = 'application/json'
      req.body = JSON.dump(payload)

      attempts = 0
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC) rescue Time.now.to_f
      Rails.logger.info("[LLM::OpenaiClient] run_prompt START model=#{model} temp=#{temperature} timeout=#{timeout}s prompt_len=#{prompt.to_s.length} max_tokens=#{max_tokens || 'nil'}") if defined?(Rails)
      begin
        attempts += 1
        res = http.request(req)
        status = (res.code.to_i rescue 0)
        body_str = res.body.to_s
        body = JSON.parse(body_str) rescue {}
        content = body.dig('choices', 0, 'message', 'content').to_s
        elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) rescue Time.now.to_f) - t0) * 1000.0
        Rails.logger.info("[LLM::OpenaiClient] run_prompt HTTP #{status} elapsed=#{elapsed.round}ms content_len=#{content.length}") if defined?(Rails)
        return content
      rescue Timeout::Error, Errno::ECONNRESET, Errno::ETIMEDOUT
        Rails.logger.warn("[LLM::OpenaiClient] run_prompt timeout retry=#{attempts}") if defined?(Rails)
        retry if attempts <= max_retries
        return ""
      rescue
        Rails.logger.error("[LLM::OpenaiClient] run_prompt unknown error") if defined?(Rails)
        return ""
      end
    end

    # Generate a better prompt suggestion given original prompt and judge data.
    # Returns { 'suggested_prompt' => String }
    def self.suggest_prompt(original_prompt, heuristic:, llm:, empirical:, model: ENV.fetch('OPENAI_MODEL', 'gpt-4o-mini'), timeout: 10)
      normalized_prompt = original_prompt.to_s.gsub(/\s+/, ' ').strip
    
      system_prompt = <<~PROMPT
        You are a Prompt Refinement Assistant.

        You will receive:
        The user’s original prompt
        The LLM judge’s reasons
        The Empirical judge’s reasons

        Your job:
        Extract Evaluation Criteria
        Clearly list what the LLM judge is rewarding (clarity, reasoning quality, relevance, etc.).
        Clearly list what the Empirical judge is rewarding (structured, consistent, correctly formatted outputs such as JSON, lists, or tables).
        VERY IMPORTANT: Output ONLY a JSON object with exactly one key: "suggested_prompt".
        - No other keys, no code fences, no explanations.
        - The value must be a refined, directly-usable prompt that is specific, feasible, unambiguous,
          and requests an output format when appropriate for consistency.

        Synthesize an Improved Prompt
        Write a single, improved prompt that satisfies both judges’ criteria simultaneously.
        The prompt must be:
        Specific – remove ambiguity and vague instructions.
        Feasible – within what an LLM can reliably perform.
        Format-explicit – specify expected structure or keys (e.g., JSON, numbered list).
        Task-aware – if the user’s input is code-related (debugging, feature creation, system design), produce a step-by-step task plan.
        Scope-checked – if the user asks for too much, recommend breaking it into smaller steps.

        Gap-Filling Rule
        Fill in all missing context you can infer directly from the given input.
        Where you cannot infer, insert placeholders in angle brackets: <placeholder>.
        Do not explicitly ask the user for more details—show them where to fill in instead.

        Output Format
        Your response must have exactly this structure:

        [Improved Prompt]
        Fix <bug description / create new method / design code / etc.> by doing:
        1. <Step 1>
        2. <Step 2>
        3. <Step 3>
      PROMPT
    
      llm_reasons = Array((llm && (llm[:reasons] || llm['reasons'])) || []).map { |r| "- #{r}" }.join("\n")
      emp_reasons = Array((empirical && (empirical[:reasons] || empirical['reasons'])) || []).map { |r| "- #{r}" }.join("\n")
    
      user_content = <<~USER
        Original prompt:
        #{normalized_prompt}
    
        LLM judge reasons:
        #{llm_reasons}
    
        Empirical judge reasons:
        #{emp_reasons}
      USER
    
      payload = {
        model: model,
        messages: [
          { role: 'system', content: system_prompt },
          { role: 'user', content: user_content }
        ],
        temperature: 0.2,
        response_format: { type: 'json_object' }
      }
    
      http = Net::HTTP.new(OPENAI_URL.host, OPENAI_URL.port)
      http.use_ssl = true
      http.read_timeout = timeout
      req = Net::HTTP::Post.new(OPENAI_URL.request_uri)
      api_key = ENV['OPENAI_API_KEY']
      req['Authorization'] = "Bearer #{api_key}" if api_key && !api_key.empty?
      req['Content-Type'] = 'application/json'
      req.body = JSON.dump(payload)
    
      res = http.request(req)
      raw_body = res.body.to_s
      body = JSON.parse(raw_body) rescue {}
      content = body.dig('choices', 0, 'message', 'content').to_s
      content = content.gsub(/\s+\z/, '').strip
    
      begin
        parsed = JSON.parse(content)
        if parsed.is_a?(Hash) && parsed['suggested_prompt'].is_a?(String) && !parsed['suggested_prompt'].strip.empty?
          return parsed
        end
      rescue JSON::ParserError
        extracted = extract_json_object(content)
        if extracted
          begin
            parsed2 = JSON.parse(extracted)
            if parsed2.is_a?(Hash) && parsed2['suggested_prompt'].is_a?(String) && !parsed2['suggested_prompt'].strip.empty?
              return parsed2
            end
          rescue JSON::ParserError
          end
        end
      end
    
      { 'suggested_prompt' => normalized_prompt }
    rescue => _
      { 'suggested_prompt' => normalized_prompt }
    end
  end
end


