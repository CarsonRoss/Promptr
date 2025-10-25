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
        Rails.cache.write(["user:verify_code", user.id].join(':'), code, expires_in: 5.minutes)
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
end


