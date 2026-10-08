# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Phones::Normalize do
  subject { described_class.new(raw).call }

  context 'when phone contains separators' do
    let(:raw) { '+7 (999) 000-00-00' }

    it { is_expected.to eq('+79990000000') }
  end

  context 'when phone is already digits' do
    let(:raw) { '79990000000' }

    it { is_expected.to eq('79990000000') }
  end
end
