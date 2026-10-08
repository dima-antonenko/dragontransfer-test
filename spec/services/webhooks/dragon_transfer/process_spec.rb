# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webhooks::DragonTransfer::Process do
  subject(:operation) { described_class.new(payload:, api_key:).call }

  let(:payload) { partner_payload('status' => 'PROCESSING') }
  let(:api_key) { 'test-api-key' }

  context 'when key is invalid' do
    let(:api_key) { 'wrong-key' }

    it { expect { operation }.to raise_error(DragonTransfer::Error, 'Not authorized') }
  end

  context 'when order is unknown' do
    it { is_expected.to be_nil }
  end

  context 'when order exists' do
    let!(:order) { create(:order, external_id: payload['id']) }

    it 'applies payload' do
      expect(operation).to have_attributes(id: order.id, status: 'PROCESSING')
    end
  end
end
