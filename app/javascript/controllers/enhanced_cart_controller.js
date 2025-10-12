import { Controller } from "@hotwired/stimulus"

// Enhanced Shopping Cart with Real-time Updates and Animations
export default class extends Controller {
  static targets = [
    "count",
    "subtotal",
    "item",
    "emptyState",
    "cartDrawer",
    "backdrop",
    "itemsList"
  ]

  static values = {
    url: String,
    checkoutUrl: String
  }

  connect() {
    this.setupEventListeners()
    this.loadCartFromStorage()
  }

  setupEventListeners() {
    // Listen for cart updates from other tabs
    window.addEventListener('storage', (e) => {
      if (e.key === 'cart_updated') {
        this.refreshCart()
      }
    })
    
    // Listen for custom cart events
    document.addEventListener('cart:updated', () => this.refreshCart())
    document.addEventListener('cart:item-added', (e) => this.showAddedNotification(e.detail))
  }

  // Add item to cart with animation
  async addItem(event) {
    event.preventDefault()
    
    const button = event.currentTarget
    const productId = button.dataset.productId || event.params?.productId
    const variantId = button.dataset.variantId
    const quantity = button.dataset.quantity || 1
    
    // Disable button during request
    button.disabled = true
    this.showLoadingState(button)
    
    try {
      const response = await fetch('/cart_items', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({
          cart_item: {
            product_id: productId,
            variant_id: variantId,
            quantity: quantity
          }
        })
      })
      
      if (!response.ok) throw new Error('Failed to add item')
      
      const data = await response.json()
      
      // Flying animation from button to cart icon
      this.animateItemToCart(button)
      
      // Update cart display
      this.updateCartData(data)
      
      // Show success notification
      this.showSuccessNotification(data.item)
      
      // Update local storage
      this.updateCartStorage()
      
      // Dispatch custom event
      this.dispatch('itemAdded', { detail: data })
      
      // Auto-open cart drawer
      setTimeout(() => this.openDrawer(), 400)
      
    } catch (error) {
      console.error('Add to cart error:', error)
      this.showErrorNotification('Failed to add item to cart')
    } finally {
      button.disabled = false
      this.hideLoadingState(button)
    }
  }

  // Update item quantity
  async updateQuantity(event) {
    const input = event.currentTarget
    const itemId = input.dataset.itemId
    const newQuantity = parseInt(input.value)
    
    if (newQuantity < 1) {
      this.removeItem({ currentTarget: input.closest('[data-item-id]') })
      return
    }
    
    // Optimistic update
    const itemRow = input.closest('[data-enhanced-cart-target="item"]')
    this.updateItemDisplay(itemRow, newQuantity)
    
    // Debounced API call
    this.debouncedUpdateQuantity(itemId, newQuantity)
  }

  debouncedUpdateQuantity = this.debounce(async (itemId, quantity) => {
    try {
      const response = await fetch(`/cart_items/${itemId}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({
          cart_item: { quantity }
        })
      })
      
      if (!response.ok) throw new Error('Failed to update quantity')
      
      const data = await response.json()
      this.updateCartData(data)
      this.updateCartStorage()
      
    } catch (error) {
      console.error('Update quantity error:', error)
      this.showErrorNotification('Failed to update quantity')
      this.refreshCart()
    }
  }, 500)

  // Remove item with confirmation
  async removeItem(event) {
    const itemElement = event.currentTarget.closest('[data-item-id]')
    const itemId = itemElement.dataset.itemId
    const itemName = itemElement.dataset.itemName
    
    // Confirm removal
    if (!confirm(`Remove "${itemName}" from cart?`)) {
      return
    }
    
    // Animate out
    itemElement.classList.add('animate-fadeOut')
    
    try {
      const response = await fetch(`/cart_items/${itemId}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': this.getCSRFToken()
        }
      })
      
      if (!response.ok) throw new Error('Failed to remove item')
      
      const data = await response.json()
      
      // Remove from DOM
      setTimeout(() => {
        itemElement.remove()
        this.updateCartData(data)
        this.checkEmptyState()
        this.updateCartStorage()
      }, 300)
      
      this.showSuccessNotification(`${itemName} removed from cart`)
      
    } catch (error) {
      console.error('Remove item error:', error)
      itemElement.classList.remove('animate-fadeOut')
      this.showErrorNotification('Failed to remove item')
    }
  }

  // Clear entire cart
  async clearCart() {
    if (!confirm('Are you sure you want to clear your cart?')) {
      return
    }
    
    try {
      const response = await fetch('/cart_items/clear', {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': this.getCSRFToken()
        }
      })
      
      if (!response.ok) throw new Error('Failed to clear cart')
      
      // Animate all items out
      this.itemTargets.forEach((item, index) => {
        setTimeout(() => {
          item.classList.add('animate-fadeOut')
        }, index * 50)
      })
      
      // Clear after animations
      setTimeout(() => {
        this.itemTargets.forEach(item => item.remove())
        this.updateCartData({ count: 0, subtotal: 0, items: [] })
        this.checkEmptyState()
        this.updateCartStorage()
      }, 500)
      
      this.showSuccessNotification('Cart cleared')
      
    } catch (error) {
      console.error('Clear cart error:', error)
      this.showErrorNotification('Failed to clear cart')
    }
  }

  // Save for later
  async saveForLater(event) {
    const button = event.currentTarget
    const itemId = button.dataset.itemId
    
    button.disabled = true
    
    try {
      const response = await fetch(`/saved_items/${itemId}/move_to_saved`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': this.getCSRFToken()
        }
      })
      
      if (!response.ok) throw new Error('Failed to save item')
      
      const data = await response.json()
      
      // Remove from cart display
      const itemElement = button.closest('[data-item-id]')
      itemElement.classList.add('animate-fadeOut')
      
      setTimeout(() => {
        itemElement.remove()
        this.updateCartData(data.cart)
        this.checkEmptyState()
      }, 300)
      
      this.showSuccessNotification('Item saved for later')
      
    } catch (error) {
      console.error('Save for later error:', error)
      button.disabled = false
      this.showErrorNotification('Failed to save item')
    }
  }

  // Open cart drawer
  openDrawer() {
    if (!this.hasCartDrawerTarget) return
    
    this.cartDrawerTarget.classList.remove('translate-x-full')
    this.cartDrawerTarget.classList.add('translate-x-0')
    
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove('hidden')
      setTimeout(() => {
        this.backdropTarget.classList.add('opacity-100')
      }, 10)
    }
    
    document.body.style.overflow = 'hidden'
    
    // Track analytics
    if (window.gtag) {
      window.gtag('event', 'view_cart', {
        event_category: 'ecommerce'
      })
    }
  }

  // Close cart drawer
  closeDrawer() {
    if (!this.hasCartDrawerTarget) return
    
    this.cartDrawerTarget.classList.add('translate-x-full')
    this.cartDrawerTarget.classList.remove('translate-x-0')
    
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove('opacity-100')
      setTimeout(() => {
        this.backdropTarget.classList.add('hidden')
      }, 300)
    }
    
    document.body.style.overflow = ''
  }

  // Toggle drawer
  toggleDrawer() {
    if (this.cartDrawerTarget.classList.contains('translate-x-0')) {
      this.closeDrawer()
    } else {
      this.openDrawer()
    }
  }

  // Proceed to checkout
  checkout() {
    if (this.hasCheckoutUrlValue) {
      window.location.href = this.checkoutUrlValue
    }
    
    // Track analytics
    if (window.gtag) {
      window.gtag('event', 'begin_checkout', {
        event_category: 'ecommerce'
      })
    }
  }

  // Update cart display
  updateCartData(data) {
    // Update count badge
    if (this.hasCountTarget) {
      this.countTargets.forEach(target => {
        target.textContent = data.count || 0
        
        // Pulse animation
        target.classList.add('animate-pulse')
        setTimeout(() => target.classList.remove('animate-pulse'), 600)
        
        // Hide/show badge based on count
        if (data.count === 0) {
          target.classList.add('hidden')
        } else {
          target.classList.remove('hidden')
        }
      })
    }
    
    // Update subtotal
    if (this.hasSubtotalTarget) {
      this.subtotalTargets.forEach(target => {
        target.textContent = this.formatCurrency(data.subtotal || 0)
      })
    }
    
    // Check if cart is empty
    this.checkEmptyState()
  }

  // Update individual item display
  updateItemDisplay(itemRow, quantity) {
    const priceElement = itemRow.querySelector('[data-item-price]')
    const totalElement = itemRow.querySelector('[data-item-total]')
    
    if (priceElement && totalElement) {
      const price = parseFloat(priceElement.dataset.itemPrice)
      const total = price * quantity
      totalElement.textContent = this.formatCurrency(total)
    }
    
    // Recalculate subtotal
    this.recalculateSubtotal()
  }

  // Recalculate cart subtotal
  recalculateSubtotal() {
    let subtotal = 0
    
    this.itemTargets.forEach(item => {
      const totalElement = item.querySelector('[data-item-total]')
      if (totalElement) {
        const total = parseFloat(totalElement.textContent.replace(/[^0-9.-]+/g, ''))
        subtotal += total
      }
    })
    
    if (this.hasSubtotalTarget) {
      this.subtotalTargets.forEach(target => {
        target.textContent = this.formatCurrency(subtotal)
      })
    }
  }

  // Check and show empty state
  checkEmptyState() {
    const hasItems = this.itemTargets.length > 0
    
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.toggle('hidden', hasItems)
    }
    
    if (this.hasItemsListTarget) {
      this.itemsListTarget.classList.toggle('hidden', !hasItems)
    }
  }

  // Animate item flying to cart
  animateItemToCart(sourceElement) {
    const cartIcon = document.querySelector('[data-cart-icon]')
    if (!cartIcon) return
    
    const clone = sourceElement.cloneNode(true)
    clone.style.position = 'fixed'
    clone.style.zIndex = '9999'
    clone.style.transition = 'all 0.6s cubic-bezier(0.22, 1, 0.36, 1)'
    
    const sourceRect = sourceElement.getBoundingClientRect()
    const cartRect = cartIcon.getBoundingClientRect()
    
    clone.style.left = sourceRect.left + 'px'
    clone.style.top = sourceRect.top + 'px'
    clone.style.width = sourceRect.width + 'px'
    clone.style.height = sourceRect.height + 'px'
    
    document.body.appendChild(clone)
    
    requestAnimationFrame(() => {
      clone.style.left = cartRect.left + 'px'
      clone.style.top = cartRect.top + 'px'
      clone.style.width = '20px'
      clone.style.height = '20px'
      clone.style.opacity = '0'
    })
    
    setTimeout(() => {
      clone.remove()
      // Shake cart icon
      cartIcon.classList.add('animate-bounce')
      setTimeout(() => cartIcon.classList.remove('animate-bounce'), 600)
    }, 600)
  }

  // Refresh cart from server
  async refreshCart() {
    try {
      const response = await fetch(this.urlValue, {
        headers: {
          'Accept': 'application/json'
        }
      })
      
      if (!response.ok) throw new Error('Failed to refresh cart')
      
      const data = await response.json()
      this.updateCartData(data)
      
    } catch (error) {
      console.error('Refresh cart error:', error)
    }
  }

  // Load cart state from localStorage
  loadCartFromStorage() {
    const stored = localStorage.getItem('cart_state')
    if (stored) {
      try {
        const data = JSON.parse(stored)
        this.updateCartData(data)
      } catch (error) {
        console.error('Error loading cart from storage:', error)
      }
    }
  }

  // Update localStorage
  updateCartStorage() {
    const cartState = {
      count: this.countTarget?.textContent || 0,
      subtotal: this.subtotalTarget?.textContent || 0,
      timestamp: Date.now()
    }
    
    localStorage.setItem('cart_state', JSON.stringify(cartState))
    localStorage.setItem('cart_updated', Date.now().toString())
  }

  // Show loading state on button
  showLoadingState(button) {
    button.dataset.originalText = button.innerHTML
    button.innerHTML = `
      <svg class="animate-spin h-5 w-5 mx-auto" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
    `
  }

  hideLoadingState(button) {
    if (button.dataset.originalText) {
      button.innerHTML = button.dataset.originalText
      delete button.dataset.originalText
    }
  }

  // Show success notification
  showSuccessNotification(message) {
    if (window.Toastify) {
      Toastify({
        text: message,
        duration: 3000,
        gravity: "top",
        position: "right",
        backgroundColor: "linear-gradient(135deg, #6B4FA9, #9C7BE3)",
        stopOnFocus: true
      }).showToast()
    }
  }

  // Show error notification
  showErrorNotification(message) {
    if (window.Toastify) {
      Toastify({
        text: message,
        duration: 3000,
        gravity: "top",
        position: "right",
        backgroundColor: "linear-gradient(135deg, #ef4444, #dc2626)",
        stopOnFocus: true
      }).showToast()
    }
  }

  // Utility functions
  getCSRFToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  formatCurrency(amount) {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(amount)
  }

  debounce(func, wait) {
    let timeout
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout)
        func(...args)
      }
      clearTimeout(timeout)
      timeout = setTimeout(later, wait)
    }
  }
}