module Rates
  class Fetch < BaseService
    def initialize(client: nil)
      @client = client
    end

    def call
      client.rate
    end
  end
end
