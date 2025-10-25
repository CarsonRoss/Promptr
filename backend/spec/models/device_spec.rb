require 'rails_helper'

RSpec.describe Device, type: :model do
  it 'validates presence and uniqueness of device_id' do
    d1 = described_class.create!(device_id: 'abc')
    expect(d1).to be_persisted
    expect { described_class.create!(device_id: 'abc') }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'derives remaining uses from guest_user and decrements when not paid' do
    g = GuestUser.create!(device_fingerprint: 'fp-1', remaining_uses: 2)
    d = described_class.create!(device_id: 'x', guest_user: g)
    expect(d.remaining_uses).to eq(2)
    d.consume_trial!
    expect(d.reload.remaining_uses).to eq(1)
    d.consume_trial!
    expect(d.reload.remaining_uses).to eq(0)
    expect(d.exhausted?).to be(true)
  end

  it 'is paid when stripe_customer_id is present and does not decrement' do
    g = GuestUser.create!(device_fingerprint: 'fp-2', remaining_uses: 1)
    d = described_class.create!(device_id: 'y', guest_user: g, stripe_customer_id: 'cus_123')
    expect(d.paid?).to be(true)
    d.consume_trial!
    expect(d.reload.remaining_uses).to eq(1)
    expect(d.exhausted?).to be(false)
  end
end


