require 'rails_helper'

RSpec.describe EmailVerificationService do
  let(:user) { User.create!(email: 'verify@example.com', password: 'password123', password_confirmation: 'password123', status: 'unpaid') }

  it 'returns false when SENDGRID_API_KEY is missing' do
    orig = ENV['SENDGRID_API_KEY']
    begin
      ENV['SENDGRID_API_KEY'] = nil
      expect(described_class.send_verification_email(user)).to be(false)
    ensure
      ENV['SENDGRID_API_KEY'] = orig
    end
  end

  it 'handles SendGrid failures gracefully' do
    orig_key = ENV['SENDGRID_API_KEY']
    orig_from = ENV['SENDGRID_FROM_EMAIL']
    begin
      ENV['SENDGRID_API_KEY'] = 'dummy'
      ENV['SENDGRID_FROM_EMAIL'] = 'no-reply@example.com'
      allow(SendGrid::API).to receive(:new).and_return(
        instance_double(SendGrid::API, client: double('client', mail: double('_', _:'send', post: double('resp', status_code: '500', body: 'error'))))
      )
      expect(described_class.send_verification_email(user)).to be(false)
    ensure
      ENV['SENDGRID_API_KEY'] = orig_key
      ENV['SENDGRID_FROM_EMAIL'] = orig_from
    end
  end
end


