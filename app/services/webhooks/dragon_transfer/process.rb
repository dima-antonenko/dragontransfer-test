module Webhooks
  module DragonTransfer
    class Process < BaseService
      def initialize(payload:, api_key:)
        @payload = payload
        @api_key = api_key
      end

      def call
        authenticate!
        order = Order.find_by(external_id: @payload["id"])
        return if order.blank?

        Orders::ApplyWebhook.new(order: order, payload: @payload).call
      end

      private

      def authenticate!
        return if ::DragonTransfer.valid_api_key?(@api_key)

        raise ::DragonTransfer::Error.new(
          "Not authorized",
          code: "not_authorized",
          http_status: 401
        )
      end
    end
  end
end
