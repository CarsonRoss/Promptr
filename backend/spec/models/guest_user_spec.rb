require 'rails_helper'

RSpec.describe GuestUser, type: :model do
  it 'requires unique device_fingerprint' do
    g1 = described_class.create!(device_fingerprint: 'fp-1', remaining_uses: 20)
    expect(g1).to be_persisted
    expect { described_class.create!(device_fingerprint: 'fp-1', remaining_uses: 20) }
      .to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'decrements remaining uses but not below zero' do
    g = described_class.create!(device_fingerprint: 'fp-2', remaining_uses: 1)
    g.decrement_uses!
    expect(g.reload.remaining_uses).to eq(0)
    g.decrement_uses!
    expect(g.reload.remaining_uses).to eq(0)
  end
end


