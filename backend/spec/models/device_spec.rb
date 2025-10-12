require 'rails_helper'

RSpec.describe Device, type: :model do
  it 'validates presence and uniqueness of device_id' do
    d1 = described_class.create!(device_id: 'abc')
    expect(d1).to be_persisted
    expect { described_class.create!(device_id: 'abc') }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'defaults to 5 remaining uses and unpaid' do
    d = described_class.create!(device_id: 'x')
    expect(d.remaining_uses).to eq(5)
    expect(d.paid).to be(false)
  end

  it 'exhausts and clamps at zero when consuming trial' do
    d = described_class.create!(device_id: 'y', remaining_uses: 1)
    d.consume_trial!
    expect(d.reload.remaining_uses).to eq(0)
    expect(d.exhausted?).to be(true)
  end

  it 'does not decrement when paid' do
    d = described_class.create!(device_id: 'z', paid: true, remaining_uses: 0)
    d.consume_trial!
    expect(d.reload.remaining_uses).to eq(0)
    expect(d.exhausted?).to be(false)
  end
end


