# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Orders', type: :request do
  let(:order) { create(:order, :kyc_pending) }
  let(:service) { instance_double(Orders::Show, call: order) }

  before { allow(Orders::Show).to receive(:new).with(id: order.id.to_s).and_return(service) }

  describe 'GET /orders/:id' do
    subject { get order_path(order) }

    it 'renders status page', :aggregate_failures do
      subject
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Заявка ##{order.id}")
    end
  end

  describe 'GET /orders/:id/verification-return' do
    subject { get verification_return_order_path(order) }

    it 'renders show' do
      subject
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Статус заявки')
    end
  end

  describe 'GET /orders/:id/invoice-return' do
    subject { get invoice_return_order_path(order) }

    it 'renders show' do
      subject
      expect(response).to have_http_status(:ok)
    end
  end
end
