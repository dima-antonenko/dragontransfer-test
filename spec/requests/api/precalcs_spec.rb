# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Precalcs', type: :request do
  describe 'POST /api/precalc' do
    subject { post '/api/precalc', params:, as: :json }

    let(:params) { { amount: 5000 } }
    let(:service) { instance_double(Precalcs::Create) }
    let(:payload) { { 'payout_amount' => '55.76', 'payin_amount' => '5000' } }

    before do
      allow(Precalcs::Create).to receive(:new).and_return(service)
      allow(service).to receive(:call).and_return(payload)
    end

    it 'returns calculation', :aggregate_failures do
      subject
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('payout_amount' => '55.76')
    end

    context 'when amount is missing' do
      let(:params) { {} }

      before { allow(Precalcs::Create).to receive(:new) }

      it 'returns argument error', :aggregate_failures do
        subject
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body).to include('code' => 'argument_error')
      end
    end

    context 'when partner returns 401' do
      let(:error) { DragonTransfer::Error.new('Not authorized', code: 'not_authorized', http_status: 401, request_id: 'req-1') }

      before { allow(service).to receive(:call).and_raise(error) }

      it 'returns partner error', :aggregate_failures do
        subject
        expect(response).to have_http_status(:unauthorized)
        expect(response.parsed_body).to include('code' => 'not_authorized', 'request_id' => 'req-1')
      end
    end

    context 'when partner is unavailable' do
      let(:error) { DragonTransfer::Error.new('down', code: 'network_error', http_status: 502) }

      before { allow(service).to receive(:call).and_raise(error) }

      it 'maps 5xx partner errors to 422' do
        subject
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
