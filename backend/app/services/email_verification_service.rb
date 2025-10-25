require 'sendgrid-ruby'
require 'cgi'

class EmailVerificationService
    # Sends a verification email with a signed token link.
    # Returns true on success, false on any failure.
    def self.send_verification_email(user)
        api_key = ENV['SENDGRID_API_KEY'].to_s
        from_email = ENV['SENDGRID_FROM_EMAIL'].presence || 'no-reply@example.com'
        frontend_url = ENV['FRONTEND_URL'].presence || 'http://localhost:5173'

        unless api_key.present?
            Rails.logger.error('[EmailVerificationService] SENDGRID_API_KEY missing')
            return false
        end

        token = user.generate_verification_token
        # Also generate a 6-digit verification code and cache it for short period
        code = format('%06d', SecureRandom.random_number(1_000_000))
        # Store under both user and email keys for compatibility
        Rails.cache.write(["user:verify_code", user.id].join(':'), code, expires_in: 10.minutes)
        Rails.cache.write(["email:verify_code", user.email.to_s.downcase.strip].join(':'), code, expires_in: 10.minutes)
        verification_link = "#{frontend_url}/verify-email?token=#{CGI.escape(token)}"

        from = SendGrid::Email.new(email: from_email)
        to = SendGrid::Email.new(email: user.email)
        subject = 'Verify your email'
        text = "Your verification code is: #{code}\n\nOr verify by clicking: #{verification_link}"
        html = "<p>Your verification code is: <strong>#{code}</strong></p><p>Or verify by clicking the link below:</p><p><a href=\"#{verification_link}\">Verify Email</a></p>"

        content = [
            SendGrid::Content.new(type: 'text/plain', value: text),
            SendGrid::Content.new(type: 'text/html', value: html)
        ]

        mail = SendGrid::Mail.new
        mail.from = from
        mail.subject = subject
        personalization = SendGrid::Personalization.new
        personalization.add_to(to)
        mail.add_personalization(personalization)
        content.each { |c| mail.add_content(c) }

        sg = SendGrid::API.new(api_key: api_key)
        response = sg.client.mail._('send').post(request_body: mail.to_json)

        code = response.status_code.to_i
        return true if code >= 200 && code < 300

        Rails.logger.error("[EmailVerificationService] SendGrid non-2xx status=#{code} body=#{response.body}")
        false
    rescue => e
        Rails.logger.error("[EmailVerificationService] error: #{e.class} #{e.message}")
        false
    end

    # Send a 6-digit code to a raw email (no user record required).
    # Caches under key: "email:verify_code:<email>"
    def self.send_code_to_email(email)
        Rails.logger.info("[EmailVerificationService] SEND CODE email=#{email}")
        api_key = ENV['SENDGRID_API_KEY'].to_s
        from_email = ENV['SENDGRID_FROM_EMAIL'].presence || 'no-reply@example.com'
        unless api_key.present?
            Rails.logger.error('[EmailVerificationService] SENDGRID_API_KEY missing')
            return false
        end
        code = format('%06d', SecureRandom.random_number(1_000_000))
        cache_key = ["email:verify_code", email.to_s.downcase.strip].join(':')
        Rails.cache.write(cache_key, code, expires_in: 10.minutes)

        from = SendGrid::Email.new(email: from_email)
        to = SendGrid::Email.new(email: email)
        subject = 'Your verification code'
        text = "Your verification code is: #{code}"
        html = "<p>Your verification code is: <strong>#{code}</strong></p>"

        mail = SendGrid::Mail.new
        mail.from = from
        mail.subject = subject
        personalization = SendGrid::Personalization.new
        personalization.add_to(to)
        mail.add_personalization(personalization)
        mail.add_content(SendGrid::Content.new(type: 'text/plain', value: text))
        mail.add_content(SendGrid::Content.new(type: 'text/html', value: html))

        sg = SendGrid::API.new(api_key: api_key)
        res = sg.client.mail._('send').post(request_body: mail.to_json)
        code_i = res.status_code.to_i
        return true if code_i >= 200 && code_i < 300
        Rails.logger.error("[EmailVerificationService] send_code_to_email non-2xx status=#{code_i} body=#{res.body}")
        false
    rescue => e
        Rails.logger.error("[EmailVerificationService] send_code_to_email error: #{e.class} #{e.message}")
        false
    end
end


