class BaseService
  def self.call(...)
    new(...).call
  end

  protected

  def client
    @client ||= DragonTransfer::Client.new
  end
end
