require 'rails_helper'

RSpec.describe 'Reactivate subscription', type: :request do
  let!(:user) { User.create!(email: 'reactivate@example.com', password: 'password123', password_confirmation: 'password123', status: 'unpaid') }

  def sign_in(user)
    token = AuthService.generate_jwt(user_id: user.id)
    cookies[:ctx_token] = token
  end

  before { sign_in(user) }

  it 'reactivates when user is unpaid but has an active Stripe subscription set to cancel at period end' do
    # Cache or discover customer id
    Rails.cache.write(["user", user.id.to_s, "stripe_customer_id"].join(':'), 'cus_123', expires_in: 1.day)

    # Stripe returns an active subscription that is cancel_at_period_end: true
    fake_sub = double('Stripe::Subscription', id: 'sub_123', current_period_end: (Time.current + 7.days).to_i, cancel_at_period_end: true)
    allow(Stripe::Subscription).to receive(:list).and_return(double(data: [fake_sub]))
    updated_sub = double('Stripe::Subscription', id: 'sub_123', current_period_end: fake_sub.current_period_end, cancel_at_period_end: false)
    allow(Stripe::Subscription).to receive(:update).with('sub_123', cancel_at_period_end: false).and_return(updated_sub)

    post '/api/v1/subscription/reactivate'
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body['reactivated']).to eq(true)

    # Status should now show not cancelled at period end
    get '/api/v1/subscription/status'
    status = JSON.parse(response.body)
    expect(status['cancel_at_period_end']).to eq(false)
  end
end


