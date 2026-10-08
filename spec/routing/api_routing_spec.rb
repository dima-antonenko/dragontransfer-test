# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API routes', type: :routing do
  it { expect(post: '/api/precalc').to route_to('api/precalcs#create') }
  it { expect(get: '/api/rate').to route_to('api/rates#show') }
  it { expect(post: '/api/orders').to route_to('api/orders#create') }
  it { expect(get: '/api/orders/1').to route_to('api/orders#show', id: '1') }
  it { expect(post: '/webhooks/dragon_transfer').to route_to('webhooks/dragon_transfer#create') }
  it { expect(get: '/orders/1/verification-return').to route_to('orders#verification_return', id: '1') }
  it { expect(get: '/orders/1/invoice-return').to route_to('orders#invoice_return', id: '1') }
end
