# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::ApplyWebhook do
  subject(:operation) { described_class.new(order:, payload:).call }

  let(:order) { create(:order) }
  let(:payload) { partner_payload('status' => 'PAYIN_SUCCESS', 'id' => order.external_id) }

  it { is_expected.to have_attributes(status: 'PAYIN_SUCCESS') }
end
