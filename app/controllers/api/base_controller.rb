module Api
  class BaseController < ApplicationController
    wrap_parameters false
    protect_from_forgery with: :null_session
    include ApiErrorHandling
  end
end
