# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Rates::Fetch do
  subject(:operation) { described_class.new(client:).call }

  let(:client) { instance_double(DragonTransfer::Client) }
  let(:payload) { { 'rate' => 0.011 } }

  before { allow(client).to receive(:rate).and_return(payload) }

  it { is_expected.to eq(payload) }
end
