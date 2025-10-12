# frozen_string_literal: true

class InventoryChannel < ApplicationCable::Channel
  def subscribed
    product = Product.find_by(id: params[:product_id])
    return reject unless product
    
    stream_for product
  end

  def unsubscribed
    stop_all_streams
  end
  
  # Broadcast stock update
  def self.broadcast_stock_update(product, variant = nil)
    stock_quantity = variant ? variant.stock_quantity : product.total_stock
    
    broadcast_to product, {
      type: 'stock_update',
      product_id: product.id,
      variant_id: variant&.id,
      stock_quantity: stock_quantity,
      available: stock_quantity > 0,
      low_stock: stock_quantity > 0 && stock_quantity <= 10,
      updated_at: Time.current
    }
  end
  
  # Broadcast price change
  def self.broadcast_price_change(product, old_price, new_price, reason = nil)
    discount_percentage = ((old_price - new_price) / old_price * 100).round(2) if old_price > new_price
    
    broadcast_to product, {
      type: 'price_change',
      product_id: product.id,
      old_price: old_price,
      new_price: new_price,
      discount_percentage: discount_percentage,
      reason: reason,
      updated_at: Time.current
    }
  end
  
  # Broadcast product update
  def self.broadcast_product_update(product)
    broadcast_to product, {
      type: 'product_update',
      product_id: product.id,
      name: product.name,
      description: product.description,
      price: product.price,
      updated_at: product.updated_at
    }
  end
end

