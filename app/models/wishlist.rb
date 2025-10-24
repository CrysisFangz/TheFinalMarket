class Wishlist < ApplicationRecord
  belongs_to :user
  has_many :wishlist_items, dependent: :destroy
  has_many :products, through: :wishlist_items

  validates :user_id, presence: true

  # Optimized has_product? using direct query to avoid loading all products
  def has_product?(product)
    wishlist_items.exists?(product: product)
  end

  # Delegate business logic to service layer
  def add_product(product, options: {})
    service = WishlistService.new
    service.add_product(user, product, options: options)
  end

  def remove_product(product, options: {})
    service = WishlistService.new
    service.remove_product(user, product, options: options)
  end

  # Get items with caching
  def items(options: {})
    service = WishlistService.new
    service.get_items(user, options: options)
  end

  private

  # Ensure wishlist exists for user
  def ensure_wishlist_exists
    user.create_wishlist! unless user.wishlist
  end
end