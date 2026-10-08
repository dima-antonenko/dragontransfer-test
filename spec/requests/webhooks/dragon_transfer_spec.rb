# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Webhooks::DragonTransfer', type: :request do
  describe 'POST /webhooks/dragon_transfer' do
    subject { post '/webhooks/dragon_transfer', params: payload, headers:, as: :json }

    let(:payload) { partner_payload('status' => 'PROCESSING') }
    let(:headers) { { 'X-Api-Key' => 'test-api-key' } }
    let(:service) { instance_double(Webhooks::DragonTransfer::Process) }

    before do
      allow(Webhooks::DragonTransfer::Process).to receive(:new).and_return(service)
      allow(service).to receive(:call)
    end

    it 'accepts notification', :aggregate_failures do
      subject
      expect(response).to have_http_status(:ok)
      expect(Webhooks::DragonTransfer::Process).to have_received(:new).with(
        hash_including(api_key: 'test-api-key')
      )
    end

    context 'when key is invalid' do
      let(:error) { DragonTransfer::Error.new('Not authorized', code: 'not_authorized', http_status: 401) }

      before { allow(service).to receive(:call).and_raise(error) }

      it 'returns 401' do
        subject
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
