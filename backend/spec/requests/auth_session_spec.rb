require 'rails_helper'

RSpec.describe "Auth session flow", type: :request do
  let!(:user) { User.create!(email: "test@example.com", password: "password123", password_confirmation: "password123", status: "unpaid") }

  it "sets cookie on login and returns authenticated session (no 304)" do
    post "/api/v1/auth/login", params: { email: user.email, password: "password123" }.to_json, headers: { "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:ok)
    # Ensure cookie is set
    expect(response.headers['Set-Cookie']).to include('ctx_token=')

    # Subsequent session call should be 200 and authenticated
    get "/api/v1/auth/session"
    expect(response.status).to_not eq(304)
    expect(response).to have_http_status(:ok)
    body = JSON.parse(response.body)
    expect(body["authenticated"]).to eq(true)
    expect(body["user"]).to be_present
    expect(body["user"]["email"]).to eq(user.email)
  end

  it "clears cookie on logout and subsequent session is unauthenticated" do
    # Log in first to set cookie
    post "/api/v1/auth/login", params: { email: user.email, password: "password123" }.to_json, headers: { "CONTENT_TYPE" => "application/json" }
    expect(response).to have_http_status(:ok)
    expect(response.headers['Set-Cookie']).to include('ctx_token=')

    # Verify authenticated
    get "/api/v1/auth/session"
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["authenticated"]).to eq(true)

    # Logout should clear cookie (Set-Cookie with deletion)
    post "/api/v1/auth/logout"
    expect(response).to have_http_status(:ok)
    expect(response.headers['Set-Cookie']).to include('ctx_token=') # deletion header present

    # Now session should be unauthenticated with cookie cleared
    get "/api/v1/auth/session"
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["authenticated"]).to eq(false)
  end
end


