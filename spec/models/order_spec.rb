# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Order, type: :model do
  subject(:order) { build(:order) }

  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to validate_presence_of(:full_name) }
  it { is_expected.to validate_presence_of(:phone_number) }
  it { is_expected.to validate_presence_of(:address) }
  it { is_expected.to validate_presence_of(:payin_amount) }
  it { is_expected.to validate_inclusion_of(:status).in_array(described_class::STATUSES) }
  it { is_expected.to allow_value('ivan@example.com').for(:email) }
  it { is_expected.not_to allow_value('not-an-email').for(:email) }
  it { is_expected.to allow_value('79990000000').for(:phone_number) }
  it { is_expected.not_to allow_value('123').for(:phone_number) }
  it { is_expected.to allow_value('TGSaGfJr7ecCQG2PYNa72CnXgScmntHS62').for(:address) }
  it { is_expected.not_to allow_value('not-trc20').for(:address) }

  describe '#terminal?' do
    it { expect(build(:order, :success)).to be_terminal }
    it { expect(build(:order, :error)).to be_terminal }
    it { expect(build(:order)).not_to be_terminal }
  end

  describe '#error_label' do
    it { expect(order.error_label).to be_nil }

    context 'when code is known' do
      before { order.error_code = 'INPUT_AMOUNT_BELOW_MIN' }

      it { expect(order.error_label).to eq('Сумма ниже минимально допустимой') }
    end

    context 'when code is unknown' do
      before { order.error_code = 'CUSTOM_CODE' }

      it { expect(order.error_label).to eq('CUSTOM_CODE') }
    end
  end

  describe '#apply_remote_payload!' do
    subject(:apply_payload) { order.apply_remote_payload!(payload) }

    let(:payload) { partner_payload('status' => 'KYC_PENDING') }

    it 'copies remote fields', :aggregate_failures do
      apply_payload
      expect(order).to have_attributes(
        status: 'KYC_PENDING',
        external_id: '0e2c6a1e-6f0b-4a7e-9a3d-5f1e2b3c4d5e',
        network: 'TRC20'
      )
      expect(order.verification_expires_at).to be_a(Time)
      expect(order.invoice_expires_at).to be_nil
    end

    context 'when incoming status is older' do
      let(:order) { build(:order, status: 'PAYIN_SUCCESS', payout_amount: '10') }
      let(:payload) { partner_payload('status' => 'PENDING', 'payout_amount' => '99') }

      it 'ignores payload', :aggregate_failures do
        apply_payload
        expect(order).to have_attributes(status: 'PAYIN_SUCCESS', payout_amount: '10')
      end
    end

    context 'when incoming status is ERROR' do
      let(:order) { build(:order, status: 'PAYIN_PENDING') }
      let(:payload) { partner_payload('status' => 'ERROR', 'error_code' => 'PAYIN_INVOICE_EXPIRED') }

      it 'applies terminal error', :aggregate_failures do
        apply_payload
        expect(order).to have_attributes(status: 'ERROR', error_code: 'PAYIN_INVOICE_EXPIRED')
      end
    end

    context 'when incoming status is blank' do
      let(:payload) { partner_payload('status' => '', 'payout_amount' => '12.3') }

      it 'keeps current status and updates amounts', :aggregate_failures do
        apply_payload
        expect(order).to have_attributes(status: 'PENDING', payout_amount: '12.3')
      end
    end

    context 'when incoming status is unknown' do
      let(:order) { build(:order, status: 'PROCESSING') }
      let(:payload) { partner_payload('status' => 'SOMETHING_NEW') }

      it { expect { apply_payload }.not_to change(order, :status) }
    end
  end

  describe '#as_api_json' do
    subject(:json) { create(:order, :error).as_api_json }

    it 'includes terminal flag and error label', :aggregate_failures do
      expect(json[:terminal]).to be(true)
      expect(json[:error_label]).to eq('Клиент не прошёл верификацию личности')
      expect(json[:status]).to eq('ERROR')
    end
  end
end
