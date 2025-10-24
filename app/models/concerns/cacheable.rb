# Concern for caching
module Cacheable
  extend ActiveSupport::Concern

  included do
    after_commit :clear_cache, on: [:create, :update, :destroy]
  end

  def cache_key
    "#{self.class.name.underscore}/#{id}"
  end

  def clear_cache
    Rails.cache.delete(cache_key)
    clear_associated_caches
  end

  private

  def clear_associated_caches
    # Override in models to clear related caches
  end
end