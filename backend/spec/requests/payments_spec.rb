require 'rails_helper'

RSpec.describe 'Payments API', type: :request do
  let(:base_path) { '/api/v1/payments' }
  let(:device_id) { 'test-device-123' }

  describe 'POST /checkout' do
    context 'with authenticated user' do
      let!(:user) do
        User.create!(email: 'test@example.com', password: 'password123', password_confirmation: 'password123', status: 'unpaid')
      end

      before do
        # Stub current_user_from_cookie to return our test user
        allow_any_instance_of(ApplicationController).to receive(:current_user_from_cookie).and_return(user)
      end

      context 'when user is unpaid' do
        it 'creates a checkout session' do
          allow(Stripe::Checkout::Session).to receive(:create).and_return(
            double(url: 'https://checkout.stripe.com/test', id: 'cs_test_123', customer: 'cus_test')
          )

          post "#{base_path}/checkout", params: { device_id: device_id }

          expect(response).to have_http_status(:ok)
          body = JSON.parse(response.body)
          expect(body['url']).to eq('https://checkout.stripe.com/test')
          expect(Stripe::Checkout::Session).to have_received(:create)
        end
      end

      context 'when user is paid' do
        before do
          user.update!(status: 'paid')
        end

        it 'returns 409 conflict' do
          post "#{base_path}/checkout", params: { device_id: device_id }

          expect(response).to have_http_status(:conflict)
          body = JSON.parse(response.body)
          expect(body['error']).to eq('already_paid')
        end
      end
    end

    context 'without authenticated user' do
      before do
        # Stub to return nil for unauthenticated users
        allow_any_instance_of(ApplicationController).to receive(:current_user_from_cookie).and_return(nil)
      end

      it 'creates a checkout session' do
        allow(Stripe::Checkout::Session).to receive(:create).and_return(
          double(url: 'https://checkout.stripe.com/test', id: 'cs_test_123', customer: 'cus_test')
        )

        post "#{base_path}/checkout", params: { device_id: device_id }

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['url']).to eq('https://checkout.stripe.com/test')
      end
    end

    it 'requires device_id' do
      post "#{base_path}/checkout", params: {}
      expect(response).to have_http_status(:bad_request)
      body = JSON.parse(response.body)
      expect(body['error']).to eq('device_id required')
    end
  end

  describe 'POST /confirm' do
    let!(:user) do
      User.create!(email: 'test@example.com', password: 'password123', password_confirmation: 'password123', status: 'unpaid')
    end

    let(:session_id) { 'cs_test_123' }
    let(:customer_id) { 'cus_test_123' }

    before do
      allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(
        double(
          'session',
          customer: customer_id,
          metadata: { 'device_id' => device_id, 'user_id' => user.id.to_s },
          respond_to?: true
        )
      )
    end

    it 'updates user status to paid' do
      post "#{base_path}/confirm", params: { session_id: session_id }

      expect(response).to have_http_status(:ok)
      expect(user.reload.status).to eq('paid')
      body = JSON.parse(response.body)
      expect(body['paid']).to eq(true)
    end

    it 'updates device with stripe customer id' do
      post "#{base_path}/confirm", params: { session_id: session_id }

      expect(response).to have_http_status(:ok)
      device = Device.find_by(device_id: device_id)
      expect(device).to be_present
      expect(device.stripe_customer_id).to eq(customer_id)
    end

    it 'handles missing session_id' do
      post "#{base_path}/confirm", params: {}
      expect(response).to have_http_status(:bad_request)
    end
  end
end

