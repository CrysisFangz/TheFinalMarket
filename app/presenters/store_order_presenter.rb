# app/presenters/store_order_presenter.rb
class StoreOrderPresenter
  def initialize(order)
    @order = order
  end

  def as_json(options = {})
    {
      id: @order.id,
      user_id: @order.user_id,
      seller_id: @order.seller_id,
      status: @order.status,
      total_amount: @order.total_amount,
      created_at: @order.created_at,
      order_items: @order.order_items.map { |item| OrderItemPresenter.new(item).as_json }
    }
  end

  private

  def method_missing(method, *args, &block)
    @order.send(method, *args, &block)
  end
end