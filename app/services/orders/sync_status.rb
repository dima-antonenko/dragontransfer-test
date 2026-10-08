module Orders
  class SyncStatus < BaseService
    def initialize(order, client: nil)
      @order = order
      @client = client
    end

    def call
      return @order if @order.external_id.blank? || @order.terminal?

      payload = client.find(id: @order.external_id)
      @order.apply_remote_payload!(payload)
      @order.save!
      @order
    end
  end
end
