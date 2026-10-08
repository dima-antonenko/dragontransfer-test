# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Show do
  subject(:operation) { described_class.new(id:, client:).call }

  let(:client) { instance_double(DragonTransfer::Client) }
  let(:order) { create(:order, :success) }
  let(:id) { order.id }

  it { is_expected.to eq(order) }

  context 'when order is missing' do
    let(:id) { 0 }

    it { expect { operation }.to raise_error(ActiveRecord::RecordNotFound) }
  end
end
