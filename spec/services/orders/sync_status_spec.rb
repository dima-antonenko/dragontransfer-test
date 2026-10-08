# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::SyncStatus do
  subject(:operation) { described_class.new(order, client:).call }

  let(:client) { instance_double(DragonTransfer::Client) }
  let(:order) { create(:order) }
  let(:payload) { partner_payload('status' => 'PAYIN_PENDING', 'id' => order.external_id) }

  before { allow(client).to receive(:find).with(id: order.external_id).and_return(payload) }

  context 'when order is active' do
    it 'updates from partner', :aggregate_failures do
      is_expected.to have_attributes(status: 'PAYIN_PENDING')
      expect(client).to have_received(:find)
    end
  end

  context 'when order has no external_id' do
    let(:order) { create(:order, :new_local) }

    before { allow(client).to receive(:find) }

    it "doesn't call partner", :aggregate_failures do
      is_expected.to eq(order)
      expect(client).not_to have_received(:find)
    end
  end

  context 'when order is terminal' do
    let(:order) { create(:order, :success) }

    before { allow(client).to receive(:find) }

    it "doesn't call partner" do
      operation
      expect(client).not_to have_received(:find)
    end
  end
end
