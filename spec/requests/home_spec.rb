# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Home', type: :request do
  describe 'GET /' do
    subject { get root_path }

    it 'renders mini app', :aggregate_failures do
      subject
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Покупка USDT')
    end
  end
end
