module Webhooks
  class DragonTransferController < ApplicationController
    wrap_parameters false
    skip_forgery_protection

    rescue_from ::DragonTransfer::Error, with: :render_webhook_error

    def create
      Webhooks::DragonTransfer::Process.new(
        payload: webhook_payload,
        api_key: request.headers["X-Api-Key"]
      ).call

      head :ok
    end

    private

    def webhook_payload
      params.permit(
        :id,
        :status,
        :address,
        :network,
        :payin_amount,
        :payin_currency,
        :payout_amount,
        :payout_currency,
        :rate,
        :invoice_url,
        :invoice_expires_at,
        :verification_url,
        :verification_expires_at,
        :error_code
      ).to_h
    end

    def render_webhook_error(error)
      head error.http_status.presence || :unauthorized
    end
  end
end
