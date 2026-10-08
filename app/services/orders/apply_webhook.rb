module Orders
  class ApplyWebhook < BaseService
    def initialize(order:, payload:)
      @order = order
      @payload = payload
    end

    def call
      @order.apply_remote_payload!(@payload)
      @order.save!
      @order
    end
  end
end
