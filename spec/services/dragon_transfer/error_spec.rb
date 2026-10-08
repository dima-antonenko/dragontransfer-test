# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DragonTransfer::Error do
  subject(:error) do
    described_class.new('boom', code: 'not_authorized', http_status: 401, request_id: 'req-1', details: 'x')
  end

  it { is_expected.to have_attributes(code: 'not_authorized', http_status: 401, request_id: 'req-1', details: 'x') }
  it { expect(error.message).to eq('boom') }
end
