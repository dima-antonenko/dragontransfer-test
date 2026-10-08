module DragonTransfer
  class Error < StandardError
    attr_reader :code, :http_status, :request_id, :details

    def initialize(message, code:, http_status:, request_id: nil, details: nil)
      super(message)
      @code = code
      @http_status = http_status
      @request_id = request_id
      @details = details
    end
  end
end
