# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Orders::Create do
  subject(:operation) { described_class.new(params:, app_host:, telegram_user_id:, client:).call }

  let(:client) { instance_double(DragonTransfer::Client) }
  let(:app_host) { 'http://www.example.com/' }
  let(:telegram_user_id) { 42 }
  let(:params) do
    {
      email: 'ivan@example.com',
      full_name: 'Иван Иванов Иванович',
      phone_number: '+7 (999) 000-00-00',
      address: 'TGSaGfJr7ecCQG2PYNa72CnXgScmntHS62',
      amount: '5000'
    }
  end
  let(:create_payload) { partner_payload }
  let(:find_payload) { partner_payload('status' => 'KYC_PENDING') }

  before do
    allow(client).to receive(:create).and_return(create_payload)
    allow(client).to receive(:find).and_return(find_payload)
  end

  context 'with success' do
    it 'creates order, asks partner and syncs status', :aggregate_failures do
      expect { operation }.to change(Order, :count).by(1)
      expect(operation).to have_attributes(
        status: 'KYC_PENDING',
        phone_number: '+79990000000',
        telegram_user_id: 42,
        external_id: create_payload['id']
      )
      expect(client).to have_received(:create).with(
        hash_including(
          email: 'ivan@example.com',
          verification_return_url: "http://www.example.com/orders/#{operation.id}/verification-return",
          invoice_return_url: "http://www.example.com/orders/#{operation.id}/invoice-return"
        )
      )
      expect(client).to have_received(:find).with(id: create_payload['id'])
    end
  end

  context 'when validation failed' do
    let(:params) { { email: 'bad', full_name: '', phone_number: '1', address: 'x', amount: '5000' } }

    it 'does not call partner', :aggregate_failures do
      expect { operation }.to raise_error(ActiveRecord::RecordInvalid)
      expect(Order.count).to eq(0)
      expect(client).not_to have_received(:create)
    end
  end

  context 'when partner create failed' do
    let(:error) { DragonTransfer::Error.new('fail', code: 'api_request_error', http_status: 422) }

    before { allow(client).to receive(:create).and_raise(error) }

    it 'destroys local order', :aggregate_failures do
      expect { operation }.to raise_error(DragonTransfer::Error)
      expect(Order.count).to eq(0)
    end
  end
end
