# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DragonTransfer::Client do
  subject(:client) { described_class.new(http_client:) }

  let(:http_client) { class_double(Faraday) }
  let(:connection) { instance_double(Faraday::Connection) }
  let(:request) { instance_double(Faraday::Request, headers: {}) }
  let(:faraday_response) do
    instance_double(Faraday::Response, success?: response_success, status: response_status, body: response_body)
  end
  let(:response_success) { true }
  let(:response_status) { 200 }
  let(:response_body) { { 'success' => true, 'payload' => payload, 'id' => 'req-1' } }
  let(:payload) { { 'payin_amount' => '5000', 'payin_currency' => 'RUB' } }

  before do
    allow(http_client).to receive(:new).with(url: 'https://test.dragontransfer.online').and_return(connection)
    allow(request).to receive(:body=)
    allow(connection).to receive(:post).and_yield(request).and_return(faraday_response)
  end

  describe '#precalc' do
    subject(:result) { client.precalc(amount: 5000) }

    context 'with success response' do
      it 'returns payload and sends api key', :aggregate_failures do
        is_expected.to eq(payload)
        expect(connection).to have_received(:post).with('/api/partners/orders/precalc')
        expect(request.headers['X-Api-Key']).to eq('test-api-key')
        expect(request).to have_received(:body=).with(amount: 5000)
      end
    end

    context 'with fee_value and fractional amount' do
      subject(:result) { client.precalc(amount: '100.5', fee_value: 1.5) }

      it 'sends numeric amount and fee' do
        result
        expect(request).to have_received(:body=).with(amount: 100.5, fee_value: 1.5)
      end
    end

    context 'with HTTP 401' do
      let(:response_success) { false }
      let(:response_status) { 401 }
      let(:response_body) do
        { 'success' => false, 'payload' => { 'code' => 'not_authorized', 'errors' => 'Not authorized' }, 'id' => 'req-1' }
      end

      it 'raises partner error', :aggregate_failures do
        expect { result }.to raise_error(DragonTransfer::Error) do |error|
          expect(error).to have_attributes(code: 'not_authorized', http_status: 401, request_id: 'req-1')
          expect(error.message).to eq('Not authorized')
        end
      end
    end

    context 'with HTTP 404 in error field' do
      let(:response_success) { false }
      let(:response_status) { 404 }
      let(:response_body) do
        { 'success' => false, 'error' => { 'code' => 'not_found', 'errors' => 'Not found' }, 'id' => 'req-1' }
      end

      it { expect { result }.to raise_error(DragonTransfer::Error, 'Not found') }
    end

    context 'with hash errors' do
      let(:response_success) { false }
      let(:response_status) { 422 }
      let(:response_body) do
        { 'success' => false, 'payload' => { 'code' => 'argument_error', 'errors' => { 'amount' => ['blank'] } }, 'id' => 'req-1' }
      end

      it { expect { result }.to raise_error(DragonTransfer::Error, '{"amount":["blank"]}') }
    end

    context 'with array errors' do
      let(:response_success) { false }
      let(:response_status) { 422 }
      let(:response_body) do
        { 'success' => false, 'payload' => { 'code' => 'argument_error', 'errors' => ['amount'] }, 'id' => 'req-1' }
      end

      it { expect { result }.to raise_error(DragonTransfer::Error, '["amount"]') }
    end

    context 'with invalid json body' do
      let(:response_success) { false }
      let(:response_status) { 500 }
      let(:response_body) { '<html>' }

      it { expect { result }.to raise_error(DragonTransfer::Error, '<html>') }
    end

    context 'with blank body' do
      let(:response_success) { false }
      let(:response_status) { 500 }
      let(:response_body) { nil }

      it { expect { result }.to raise_error(DragonTransfer::Error, 'Ошибка Partner API') }
    end

    context 'with zero status' do
      let(:response_success) { false }
      let(:response_status) { 0 }
      let(:response_body) { {} }

      it 'maps to 502' do
        expect { result }.to raise_error(DragonTransfer::Error) do |error|
          expect(error).to have_attributes(http_status: 502, code: 'unknown')
        end
      end
    end

    context 'when Faraday raises' do
      before { allow(connection).to receive(:post).and_raise(Faraday::TimeoutError.new('timeout')) }

      it 'retries an idempotent call and hides the exception class', :aggregate_failures do
        expect { result }.to raise_error(DragonTransfer::Error, 'Не удалось связаться с DragonTransfer. Попробуйте ещё раз.')
        expect(connection).to have_received(:post).twice
      end
    end

    context 'when the TLS handshake fails once' do
      before do
        calls = 0
        allow(connection).to receive(:post) do |&block|
          block&.call(request)
          calls += 1
          raise Faraday::ConnectionFailed, 'Net::OpenTimeout' if calls == 1

          faraday_response
        end
      end

      it 'opens a new connection and returns the payload' do
        expect(result).to eq(payload)
      end
    end

    context 'with a gateway HTML response that then succeeds' do
      let(:gateway_response) do
        instance_double(Faraday::Response, success?: false, status: 502, body: '<!DOCTYPE html>Bad Gateway')
      end

      before do
        responses = [ gateway_response, faraday_response ]
        allow(connection).to receive(:post) do |&block|
          block&.call(request)
          responses.shift
        end
      end

      it { is_expected.to eq(payload) }
    end
  end

  describe '#rate' do
    subject(:result) { client.rate }

    let(:payload) { { 'rate' => 0.01 } }

    it { is_expected.to eq('rate' => 0.01) }
  end

  describe '#create' do
    subject(:result) { client.create(email: 'a@b.c', amount: '5000', unused: nil) }

    let(:payload) { partner_payload }

    it 'compacts nils and casts amount' do
      result
      expect(request).to have_received(:body=).with(hash_including(email: 'a@b.c', amount: 5000))
    end

    context 'when the partner times out after the request is sent' do
      before { allow(connection).to receive(:post).and_raise(Faraday::TimeoutError.new('timeout')) }

      it 'does not repeat order creation', :aggregate_failures do
        expect { result }.to raise_error(DragonTransfer::Error, /Не удалось связаться с DragonTransfer/)
        expect(connection).to have_received(:post).once
      end
    end

    context 'when the connection fails before the request is sent' do
      before do
        calls = 0
        allow(connection).to receive(:post) do |&block|
          block&.call(request)
          calls += 1
          raise Faraday::ConnectionFailed, 'Net::OpenTimeout' if calls == 1

          faraday_response
        end
      end

      it { is_expected.to eq(payload) }
    end
  end

  describe '#find' do
    subject(:result) { client.find(id: 'order-id') }

    let(:payload) { partner_payload }

    it 'posts find payload' do
      result
      expect(request).to have_received(:body=).with(id: 'order-id')
    end
  end
end
