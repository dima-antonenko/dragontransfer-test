# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DragonTransfer do
  describe '.config' do
    subject(:config) { described_class.config }

    it 'reads ENV until reset', :aggregate_failures do
      expect(config).to have_attributes(
        api_key: 'test-api-key',
        base_url: 'https://test.dragontransfer.online'
      )
      expect(described_class.config).to equal(config)

      described_class.reset_config!
      expect(described_class.config).not_to equal(config)
    end
  end

  describe '.valid_api_key?' do
    subject { described_class.valid_api_key?(value) }

    context 'when key matches' do
      let(:value) { 'test-api-key' }

      it { is_expected.to be(true) }
    end

    context 'when key is blank or different' do
      it { expect(described_class.valid_api_key?(nil)).to be(false) }
      it { expect(described_class.valid_api_key?('')).to be(false) }
      it { expect(described_class.valid_api_key?('short')).to be(false) }
      it { expect(described_class.valid_api_key?('test-api-key!')).to be(false) }
    end

    context 'when configured secret is blank' do
      let(:value) { 'test-api-key' }

      before do
        allow(described_class).to receive(:config).and_return(
          DragonTransfer::Config.new(base_url: 'https://example.com', api_key: '')
        )
      end

      it { is_expected.to be(false) }
    end
  end
end
