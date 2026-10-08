module Api
  class RatesController < BaseController
    def show
      render json: Rates::Fetch.new.call
    end
  end
end
