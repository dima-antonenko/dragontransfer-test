module Api
  class OrdersController < BaseController
    def create
      order = Orders::Create.new(
        params: order_params,
        app_host: app_host,
        telegram_user_id: params[:telegram_user_id]
      ).call

      render json: order.as_api_json, status: :created
    end

    def show
      order = Orders::Show.new(id: params[:id]).call
      render json: order.as_api_json
    end

    private

    def order_params
      params.permit(:email, :full_name, :phone_number, :address, :amount)
    end

    def app_host
      ENV["APP_HOST"].presence || request.base_url
    end
  end
end
