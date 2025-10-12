# frozen_string_literal: true

class CartChannel < ApplicationCable::Channel
  def subscribed
    return reject unless current_user
    
    stream_for current_user
  end

  def unsubscribed
    stop_all_streams
  end
  
  # Broadcast cart update
  def self.broadcast_cart_update(user, cart)
    broadcast_to user, {
      type: 'cart_update',
      total_items: cart.cart_items.sum(:quantity),
      subtotal: cart.cart_items.sum { |item| item.quantity * item.product.price },
      updated_at: Time.current
    }
  end
end

