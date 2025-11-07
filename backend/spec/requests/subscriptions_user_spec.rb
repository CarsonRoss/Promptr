require 'rails_helper'

RSpec.describe 'User-based subscription management', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let!(:user) { User.create!(email: 'test@example.com', password: 'password123', password_confirmation: 'password123', status: 'paid') }

  def sign_in(user)
    token = AuthService.generate_jwt(user_id: user.id)
    cookies[:ctx_token] = token
  end

  def iso_time(t)
    t.utc.iso8601
  end

  before do
    sign_in(user)
  end

  describe 'GET /api/v1/subscription/status' do
    it 'returns active when user is paid and not cancelled' do
      get '/api/v1/subscription/status'
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['active']).to eq(true)
      expect(json['cancel_at_period_end']).to eq(false)
    end
  end

  describe 'cancel flow keeps user paid until access end, then flips to unpaid' do
    it 'cancels at period end and flips to unpaid after current_period_end' do
      # Stub Stripe to provide a subscription and update result
      fake_sub = double('Stripe::Subscription', id: 'sub_123', current_period_end: (Time.current + 10.days).to_i, cancel_at_period_end: false)
      allow(Stripe::Subscription).to receive(:list).and_return(double(data: [fake_sub]))
      updated_sub = double('Stripe::Subscription', id: 'sub_123', current_period_end: fake_sub.current_period_end, cancel_at_period_end: true)
      allow(Stripe::Subscription).to receive(:update).with('sub_123', cancel_at_period_end: true).and_return(updated_sub)

      # Cache a user-level stripe customer id so cancel can proceed
      Rails.cache.write(["user", user.id.to_s, "stripe_customer_id"].join(':'), 'cus_abc', expires_in: 1.day)

      post '/api/v1/subscription/cancel'
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['cancelled']).to eq(true)
      expect(Time.parse(json['access_until']).utc.to_i).to eq(fake_sub.current_period_end)

      # Still paid before end
      get '/api/v1/auth/session'
      sess = JSON.parse(response.body)
      expect(sess['authenticated']).to eq(true)
      expect(sess.dig('user', 'status')).to eq('paid')

      # After end, session should report unpaid and persist it
      travel_to(Time.at(fake_sub.current_period_end + 1)) do
        get '/api/v1/auth/session'
        sess2 = JSON.parse(response.body)
        expect(sess2['authenticated']).to eq(true)
        expect(sess2.dig('user', 'status')).to eq('unpaid')
        expect(user.reload.status).to eq('unpaid')
      end
    end
  end
end


