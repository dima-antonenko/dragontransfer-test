# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BaseService do
  describe '.call' do
    let(:service_class) do
      Class.new(described_class) do
        def initialize(value)
          @value = value
        end

        def call
          @value
        end
      end
    end

    it { expect(service_class.call('ok')).to eq('ok') }
  end
end
