class Item < ApplicationRecord
  include CircuitBreaker
  include Retryable

  belongs_to :user
  belongs_to :category
  has_many :cart_items, dependent: :destroy
  has_many :order_items, dependent: :restrict_with_error
  has_many :reviews, dependent: :destroy
  has_many_attached :images

  # Enums
  enum status: {
    draft: 0,
    active: 1,
    sold: 2,
    inactive: 3
  }

  enum condition: {
    new_with_tags: 0,
    new_without_tags: 1,
    like_new: 2,
    very_good: 3,
    good: 4,
    acceptable: 5
  }

  # Validations
  validates :name, presence: true, length: { minimum: 3, maximum: 100 }
  validates :description, presence: true, length: { minimum: 10, maximum: 2000 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true
  validates :condition, presence: true
  validates :images, content_type: [:png, :jpg, :jpeg], size: { less_than: 5.megabytes }

  # Enhanced scopes with caching
  scope :active, -> { where(status: :active) }
  scope :by_category, ->(category_id) { where(category_id: category_id) }
  scope :by_seller, ->(user_id) { where(user_id: user_id) }
  scope :price_range, ->(min, max) { where(price: min..max) }

  # Caching
  after_create :clear_item_cache
  after_update :clear_item_cache
  after_destroy :clear_item_cache

  # Lifecycle callbacks
  after_create :publish_created_event
  after_update :publish_updated_event
  after_destroy :publish_destroyed_event

  def average_rating
    ItemInventoryService.get_average_rating(self)
  end

  def self.cached_find(id)
    Rails.cache.fetch("item:#{id}", expires_in: 30.minutes) do
      find_by(id: id)
    end
  end

  def self.cached_active
    ItemManagementService.get_active_items
  end

  def self.cached_by_user(user_id)
    ItemManagementService.get_items_by_user(user_id)
  end

  def self.cached_by_category(category_id)
    ItemManagementService.get_items_by_category(category_id)
  end

  def self.search(query, filters = {})
    ItemManagementService.search_items(query, filters)
  end

  def self.get_stats(user_id = nil)
    ItemManagementService.get_item_stats(user_id)
  end

  def activate!
    ItemManagementService.activate_item(self)
  end

  def deactivate!
    ItemManagementService.deactivate_item(self)
  end

  def mark_sold!
    ItemManagementService.mark_item_sold(self)
  end

  def update_inventory(quantity_change, reason = 'manual_update')
    ItemInventoryService.update_stock_quantity(self, quantity_change, reason)
  end

  def reserve_stock(quantity, reservation_id = nil)
    ItemInventoryService.reserve_stock(self, quantity, reservation_id)
  end

  def release_stock(quantity, reservation_id = nil)
    ItemInventoryService.release_stock(self, quantity, reservation_id)
  end

  def inventory_status
    ItemInventoryService.get_inventory_status(self)
  end

  def sales_performance(period = 30)
    ItemInventoryService.get_sales_performance(self, period)
  end

  def image_analysis
    ItemInventoryService.get_image_analysis(self)
  end

  def rating_distribution
    ItemInventoryService.get_rating_distribution(self)
  end

  def presenter
    @presenter ||= ItemPresenter.new(self)
  end

  private

  def set_default_status
    self.status ||= :draft
  end

  def clear_item_cache
    ItemManagementService.clear_management_cache
    ItemInventoryService.clear_inventory_cache(id)

    # Clear related caches
    Rails.cache.delete("item:#{id}")
    Rails.cache.delete("items:user:#{user_id}")
    Rails.cache.delete("items:category:#{category_id}")
  end

  def publish_created_event
    EventPublisher.publish('item.created', {
      item_id: id,
      user_id: user_id,
      category_id: category_id,
      name: name,
      price: price,
      status: status,
      condition: condition,
      created_at: created_at
    })
  end

  def publish_updated_event
    EventPublisher.publish('item.updated', {
      item_id: id,
      user_id: user_id,
      category_id: category_id,
      name: name,
      price: price,
      status: status,
      condition: condition,
      updated_at: updated_at
    })
  end

  def publish_destroyed_event
    EventPublisher.publish('item.destroyed', {
      item_id: id,
      user_id: user_id,
      category_id: category_id,
      name: name,
      price: price,
      status: status,
      condition: condition
    })
  end
end
