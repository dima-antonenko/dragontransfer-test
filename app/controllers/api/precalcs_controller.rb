module Api
  class PrecalcsController < BaseController
    def create
      payload = Precalcs::Create.new(amount: params.require(:amount)).call
      render json: payload
    end
  end
end
