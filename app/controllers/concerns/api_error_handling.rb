module ApiErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from DragonTransfer::Error, with: :render_dragon_transfer_error
    rescue_from ActiveRecord::RecordInvalid, with: :render_validation_error
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
    rescue_from ArgumentError, with: :render_argument_error
    rescue_from ActionController::ParameterMissing, with: :render_parameter_missing
  end

  private

  def render_dragon_transfer_error(error)
    status = error.http_status.between?(400, 499) ? error.http_status : :unprocessable_content
    render json: {
      error: error.message,
      code: error.code,
      request_id: error.request_id
    }, status: status
  end

  def render_validation_error(error)
    render json: {
      error: error.record.errors.full_messages.to_sentence,
      code: "argument_error"
    }, status: :unprocessable_content
  end

  def render_not_found
    render json: { error: "Заявка не найдена", code: "not_found" }, status: :not_found
  end

  def render_argument_error(error)
    render json: { error: error.message, code: "argument_error" }, status: :unprocessable_content
  end

  def render_parameter_missing(error)
    render json: { error: "Не передан параметр #{error.param}", code: "argument_error" }, status: :unprocessable_content
  end
end
