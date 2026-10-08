# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Precalcs::Create do
  subject(:operation) { described_class.new(amount:, client:).call }

  let(:client) { instance_double(DragonTransfer::Client) }
  let(:amount) { 5000 }
  let(:payload) { { 'payout_amount' => '55.76' } }

  before { allow(client).to receive(:precalc).with(amount:).and_return(payload) }

  it { is_expected.to eq(payload) }
end
