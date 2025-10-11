import { Controller } from "@hotwired/stimulus"
import consumer from "../channels/consumer"

export default class extends Controller {
  static targets = ["stock", "availability", "addToCart"]
  static values = {
    productId: Number
  }

  connect() {
    this.subscribeToInventory()
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  subscribeToInventory() {
    this.subscription = consumer.subscriptions.create(
      { 
        channel: "InventoryChannel", 
        product_id: this.productIdValue 
      },
      {
        received: (data) => this.handleUpdate(data)
      }
    )
  }

  handleUpdate(data) {
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
    if (this.hasStockTarget) {
      this.stockTarget.textContent = data.stock_quantity
      
      // Add visual feedback
      this.stockTarget.classList.add('flash-update')
      setTimeout(() => {
        this.stockTarget.classList.remove('flash-update')
      }, 1000)
    }

    // Update availability status
    if (this.hasAvailabilityTarget) {
      if (data.available) {
        this.availabilityTarget.textContent = 'In Stock'
        this.availabilityTarget.className = 'badge bg-success'
        
        if (data.low_stock) {
          this.availabilityTarget.textContent = `Only ${data.stock_quantity} left!`
          this.availabilityTarget.className = 'badge bg-warning'
        }
      } else {
        this.availabilityTarget.textContent = 'Out of Stock'
        this.availabilityTarget.className = 'badge bg-danger'
      }
    }

    // Enable/disable add to cart button
    if (this.hasAddToCartTarget) {
      this.addToCartTarget.disabled = !data.available
    }

    // Show notification
    if (!data.available) {
      this.showNotification('This item is now out of stock', 'warning')
    } else if (data.low_stock) {
      this.showNotification(`Hurry! Only ${data.stock_quantity} left in stock`, 'info')
    }
  }

  updatePrice(data) {
    const priceElement = this.element.querySelector('[data-price]')
    if (priceElement) {
      const oldPrice = parseFloat(priceElement.dataset.price)
      priceElement.dataset.price = data.new_price
      priceElement.textContent = `$${data.new_price.toFixed(2)}`
      
      // Show discount badge if price decreased
      if (data.discount_percentage) {
        const discountBadge = document.createElement('span')
        discountBadge.className = 'badge bg-danger ms-2'
        discountBadge.textContent = `-${data.discount_percentage}%`
        priceElement.appendChild(discountBadge)
        
        this.showNotification(
          `Price dropped by ${data.discount_percentage}%!`, 
          'success'
        )
      }
      
      // Add flash animation
      priceElement.classList.add('flash-update', 'text-success')
      setTimeout(() => {
        priceElement.classList.remove('flash-update', 'text-success')
      }, 2000)
    }
  }

  updateProduct(data) {
    // Reload product details if major update
    if (confirm('This product has been updated. Reload to see changes?')) {
      window.location.reload()
    }
  }

  showNotification(message, type = 'info') {
    // Create toast notification
    const toast = document.createElement('div')
    toast.className = `toast align-items-center text-white bg-${type} border-0`
    toast.setAttribute('role', 'alert')
    toast.innerHTML = `
      <div class="d-flex">
        <div class="toast-body">${message}</div>
        <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
      </div>
    `
    
    const container = document.querySelector('.toast-container') || this.createToastContainer()
    container.appendChild(toast)
    
    const bsToast = new bootstrap.Toast(toast)
    bsToast.show()
    
    toast.addEventListener('hidden.bs.toast', () => {
      toast.remove()
    })
  }

  createToastContainer() {
    const container = document.createElement('div')
    container.className = 'toast-container position-fixed top-0 end-0 p-3'
    document.body.appendChild(container)
    return container
  }
}

