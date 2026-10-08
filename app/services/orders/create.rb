module Orders
  class Create < BaseService
    def initialize(params:, app_host:, telegram_user_id: nil, client: nil)
      @params = params
      @app_host = app_host.to_s.chomp("/")
      @telegram_user_id = telegram_user_id
      @client = client
    end

    def call
      order = build_order
      order.save!

      payload = client.create(remote_params_for(order))
      order.apply_remote_payload!(payload)
      order.save!
      Orders::SyncStatus.new(order, client: client).call
      order
    rescue DragonTransfer::Error
      order&.destroy
      raise
    end

    private

    def build_order
      Order.new(
        status: "NEW",
        email: @params[:email].to_s.strip,
        full_name: @params[:full_name].to_s.strip,
        phone_number: Phones::Normalize.new(@params[:phone_number]).call,
        address: @params[:address].to_s.strip,
        payin_amount: BigDecimal(@params[:amount].to_s).to_s("F"),
        payin_currency: "RUB",
        telegram_user_id: @telegram_user_id
      )
    end

    def remote_params_for(order)
      {
        email: order.email,
        address: order.address,
        amount: order.payin_amount,
        full_name: order.full_name,
        phone_number: order.phone_number,
        verification_return_url: "#{@app_host}/orders/#{order.id}/verification-return",
        invoice_return_url: "#{@app_host}/orders/#{order.id}/invoice-return"
      }
    end
  end
end
