import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = ["stock", "availability", "addToCart", "lowStockBadge"]
  static values = {
    productId: Number,
    variantId: Number,
    currentStock: Number
  }

  connect() {
    this.setupInventoryChannel()
    this.updateDisplay()
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  setupInventoryChannel() {
    this.subscription = consumer.subscriptions.create(
      { 
        channel: "InventoryChannel", 
        product_id: this.productIdValue 
      },
      {
        received: (data) => this.handleInventoryUpdate(data)
      }
    )
  }

  handleInventoryUpdate(data) {
    console.log('[Inventory] Update received:', data)
    
    switch(data.type) {
      case 'stock_update':
        this.updateStock(data)
        break
      case 'price_change':
        this.updatePrice(data)
        break
      case 'product_update':
        this.updateProduct(data)
        break
    }
  }

  updateStock(data) {
    // Update stock quantity
    this.currentStockValue = data.stock_quantity
    
    // Update stock display
    if (this.hasStockTarget) {
      this.stockTarget.textContent = data.stock_quantity
      
      // Animate the change
      this.stockTarget.classList.add('stock-updated')
      setTimeout(() => {
        this.stockTarget.classList.remove('stock-updated')
      }, 1000)
    }
    
    // Update availability
    if (this.hasAvailabilityTarget) {
      if (data.available) {
        this.availabilityTarget.textContent = 'In Stock'
        this.availabilityTarget.classList.remove('out-of-stock')
        this.availabilityTarget.classList.add('in-stock')
      } else {
        this.availabilityTarget.textContent = 'Out of Stock'
        this.availabilityTarget.classList.remove('in-stock')
        this.availabilityTarget.classList.add('out-of-stock')
      }
    }
    
    // Update add to cart button
    if (this.hasAddToCartTarget) {
      this.addToCartTarget.disabled = !data.available
      this.addToCartTarget.textContent = data.available ? 'Add to Cart' : 'Out of Stock'
    }
    
    // Show/hide low stock badge
    if (this.hasLowStockBadgeTarget) {
      if (data.low_stock && data.available) {
        this.lowStockBadgeTarget.classList.remove('d-none')
        this.lowStockBadgeTarget.textContent = `Only ${data.stock_quantity} left!`
      } else {
        this.lowStockBadgeTarget.classList.add('d-none')
      }
    }
    
    // Show notification
    this.showNotification(`Stock updated: ${data.stock_quantity} available`, 'info')
  }

  updatePrice(data) {
    const priceElement = document.querySelector(`[data-product-id="${data.product_id}"] .product-price`)
    
    if (priceElement) {
      const oldPrice = parseFloat(priceElement.textContent.replace(/[^0-9.]/g, ''))
      const newPrice = data.new_price
      
      // Animate price change
      priceElement.classList.add('price-changing')
      
      setTimeout(() => {
        priceElement.textContent = `$${newPrice.toFixed(2)}`
        priceElement.classList.remove('price-changing')
        priceElement.classList.add('price-changed')
        
        setTimeout(() => {
          priceElement.classList.remove('price-changed')
        }, 2000)
      }, 300)
      
      // Show discount badge if price decreased
      if (data.discount_percentage) {
        this.showDiscountBadge(data.discount_percentage)
      }
      
      // Show notification
      const message = newPrice < oldPrice 
        ? `Price dropped to $${newPrice.toFixed(2)}! Save ${data.discount_percentage}%`
        : `Price updated to $${newPrice.toFixed(2)}`
      
      this.showNotification(message, newPrice < oldPrice ? 'success' : 'info')
    }
  }

  updateProduct(data) {
    // Reload product details if major update
    if (confirm('This product has been updated. Reload to see changes?')) {
      window.location.reload()
    }
  }

  updateDisplay() {
    // Initial display update based on current stock
    if (this.hasStockTarget) {
      this.stockTarget.textContent = this.currentStockValue
    }
    
    if (this.hasAvailabilityTarget) {
      const available = this.currentStockValue > 0
      this.availabilityTarget.textContent = available ? 'In Stock' : 'Out of Stock'
      this.availabilityTarget.classList.toggle('in-stock', available)
      this.availabilityTarget.classList.toggle('out-of-stock', !available)
    }
    
    if (this.hasAddToCartTarget) {
      const available = this.currentStockValue > 0
      this.addToCartTarget.disabled = !available
    }
    
    if (this.hasLowStockBadgeTarget) {
      const lowStock = this.currentStockValue > 0 && this.currentStockValue <= 10
      this.lowStockBadgeTarget.classList.toggle('d-none', !lowStock)
      if (lowStock) {
        this.lowStockBadgeTarget.textContent = `Only ${this.currentStockValue} left!`
      }
    }
  }

  showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div')
    notification.className = `alert alert-${type} alert-dismissible fade show inventory-notification`
    notification.innerHTML = `
      ${message}
      <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `
    
    // Add to page
    const container = document.querySelector('.notifications-container') || document.body
    container.appendChild(notification)
    
    // Auto-dismiss after 5 seconds
    setTimeout(() => {
      notification.classList.remove('show')
      setTimeout(() => notification.remove(), 300)
    }, 5000)
  }

  showDiscountBadge(percentage) {
    const badge = document.createElement('span')
    badge.className = 'badge bg-danger discount-badge'
    badge.textContent = `-${percentage}%`
    
    const priceContainer = document.querySelector(`[data-product-id="${this.productIdValue}"] .price-container`)
    if (priceContainer) {
      priceContainer.appendChild(badge)
      
      // Remove after 10 seconds
      setTimeout(() => {
        badge.classList.add('fade-out')
        setTimeout(() => badge.remove(), 300)
      }, 10000)
    }
  }

  // Manual refresh
  refresh() {
    fetch(`/api/products/${this.productIdValue}/inventory`)
      .then(response => response.json())
      .then(data => {
        this.currentStockValue = data.stock_quantity
        this.updateDisplay()
      })
      .catch(error => {
        console.error('[Inventory] Refresh failed:', error)
      })
  }
}

