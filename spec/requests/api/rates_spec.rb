# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Rates', type: :request do
  describe 'GET /api/rate' do
    subject { get '/api/rate' }

    let(:service) { instance_double(Rates::Fetch) }

    before do
      allow(Rates::Fetch).to receive(:new).and_return(service)
      allow(service).to receive(:call).and_return('rate' => 0.01, 'payin_currency' => 'RUB')
    end

    it 'returns rate', :aggregate_failures do
      subject
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('rate' => 0.01)
    end
  end
end
