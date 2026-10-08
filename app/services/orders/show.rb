module Orders
  class Show < BaseService
    def initialize(id:, client: nil)
      @id = id
      @client = client
    end

    def call
      order = Order.find(@id)
      Orders::SyncStatus.new(order, client: client).call
    end
  end
end
