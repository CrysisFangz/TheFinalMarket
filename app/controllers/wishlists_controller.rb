class WishlistsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_wishlist
  before_action :set_product, only: [:add_item, :remove_item]

  def show
    service = WishlistService.new
    result = service.get_items(current_user, options: { includes: { product: [:user, :variants] } })
    @wishlist_items = result.success? ? result.value! : []
  end

  def add_item
    service = WishlistService.new
    result = service.add_product(current_user, @product)

    if result.success?
      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, notice: 'Product added to wishlist.') }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("wishlist_button_#{@product.id}",
          partial: 'products/wishlist_button',
          locals: { product: @product }) }
      end
    else
      redirect_back(fallback_location: root_path, alert: result.failure.message)
    end
  end

  def remove_item
    service = WishlistService.new
    result = service.remove_product(current_user, @product)

    if result.success?
      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, notice: 'Product removed from wishlist.') }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("wishlist_button_#{@product.id}",
          partial: 'products/wishlist_button',
          locals: { product: @product }) }
      end
    else
      redirect_back(fallback_location: root_path, alert: result.failure.message)
    end
  end

  private

  def set_wishlist
    @wishlist = current_user.wishlist || current_user.create_wishlist
  end

  def set_product
    @product = Product.find(params[:product_id])
  end
end