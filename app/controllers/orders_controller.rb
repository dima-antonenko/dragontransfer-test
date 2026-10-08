class OrdersController < ApplicationController
  def show
    @order = Orders::Show.new(id: params[:id]).call
  end

  def verification_return
    @order = Orders::Show.new(id: params[:id]).call
    render :show
  end

  def invoice_return
    @order = Orders::Show.new(id: params[:id]).call
    render :show
  end
end
