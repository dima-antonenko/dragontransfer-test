module Precalcs
  class Create < BaseService
    def initialize(amount:, client: nil)
      @amount = amount
      @client = client
    end

    def call
      client.precalc(amount: @amount)
    end
  end
end
