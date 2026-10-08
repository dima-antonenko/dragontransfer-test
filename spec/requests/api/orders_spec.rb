# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::Orders', type: :request do
  let(:order) { create(:order, :kyc_pending) }

  describe 'POST /api/orders' do
    subject { post '/api/orders', params:, as: :json }

    let(:service) { instance_double(Orders::Create) }
    let(:params) do
      {
        email: 'ivan@example.com',
        full_name: 'Иван Иванов Иванович',
        phone_number: '79990000000',
        address: 'TGSaGfJr7ecCQG2PYNa72CnXgScmntHS62',
        amount: 5000,
        telegram_user_id: 7
      }
    end

    before do
      allow(Orders::Create).to receive(:new).and_return(service)
      allow(service).to receive(:call).and_return(order)
    end

    it 'creates order', :aggregate_failures do
      subject
      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('id' => order.id, 'status' => 'KYC_PENDING')
      expect(Orders::Create).to have_received(:new).with(
        hash_including(app_host: 'http://www.example.com', telegram_user_id: 7)
      )
    end

    context 'when record is invalid' do
      let(:invalid) { Order.new }
      let(:error) do
        invalid.validate
        ActiveRecord::RecordInvalid.new(invalid)
      end

      before { allow(service).to receive(:call).and_raise(error) }

      it 'returns validation error', :aggregate_failures do
        subject
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body).to include('code' => 'argument_error')
      end
    end

    context 'when amount cannot be parsed' do
      before { allow(service).to receive(:call).and_raise(ArgumentError, 'invalid value for BigDecimal') }

      it 'returns argument error', :aggregate_failures do
        subject
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body).to include('code' => 'argument_error')
      end
    end
  end

  describe 'GET /api/orders/:id' do
    subject { get "/api/orders/#{id}" }

    let(:id) { order.id }
    let(:service) { instance_double(Orders::Show) }

    before do
      allow(Orders::Show).to receive(:new).with(id: id.to_s).and_return(service)
      allow(service).to receive(:call).and_return(order)
    end

    it 'returns order', :aggregate_failures do
      subject
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('external_id' => order.external_id)
    end

    context 'when order is missing' do
      before { allow(service).to receive(:call).and_raise(ActiveRecord::RecordNotFound) }

      it 'returns not found', :aggregate_failures do
        subject
        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body).to include('code' => 'not_found')
      end
    end
  end
end
