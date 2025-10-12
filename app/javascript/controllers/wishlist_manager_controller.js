import { Controller } from "@hotwired/stimulus"

// Advanced Wishlist Management System
// Supports multiple wishlists, collections, and social sharing
export default class extends Controller {
  static targets = [
    "button",
    "icon",
    "count",
    "modal",
    "collectionList",
    "createForm"
  ]

  static values = {
    productId: Number,
    inWishlist: Boolean,
    url: String
  }

  connect() {
    this.updateButtonState()
  }

  // Toggle item in wishlist
  async toggle(event) {
    event?.preventDefault()
    
    const button = event.currentTarget
    const productId = button.dataset.productId || this.productIdValue
    
    // Optimistic UI update
    this.startAnimation()
    
    try {
      if (this.inWishlistValue) {
        await this.removeFromWishlist(productId)
      } else {
        await this.addToWishlist(productId)
      }
    } catch (error) {
      console.error('Wishlist toggle error:', error)
      this.showErrorNotification('Failed to update wishlist')
      // Revert optimistic update
      this.inWishlistValue = !this.inWishlistValue
      this.updateButtonState()
    }
  }

  // Add product to wishlist
  async addToWishlist(productId, collectionId = null) {
    const response = await fetch(`/wishlist/add_item/${productId}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken()
      },
      body: JSON.stringify({
        collection_id: collectionId
      })
    })
    
    if (!response.ok) throw new Error('Failed to add to wishlist')
    
    const data = await response.json()
    
    this.inWishlistValue = true
    this.updateButtonState()
    this.updateCount(data.count)
    this.showSuccessNotification('Added to wishlist ❤️')
    this.playHeartAnimation()
    
    // Track analytics
    this.trackWishlistAdd(productId)
    
    return data
  }

  // Remove product from wishlist
  async removeFromWishlist(productId) {
    const response = await fetch(`/wishlist/remove_item/${productId}`, {
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': this.getCSRFToken()
      }
    })
    
    if (!response.ok) throw new Error('Failed to remove from wishlist')
    
    const data = await response.json()
    
    this.inWishlistValue = false
    this.updateButtonState()
    this.updateCount(data.count)
    this.showSuccessNotification('Removed from wishlist')
    
    // Track analytics
    this.trackWishlistRemove(productId)
    
    return data
  }

  // Show collection selector modal
  showCollectionSelector(event) {
    event.preventDefault()
    
    if (!this.hasModalTarget) {
      this.createModal()
    }
    
    this.loadCollections()
    this.modalTarget.classList.remove('hidden')
    this.modalTarget.classList.add('flex')
    
    // Animate in
    requestAnimationFrame(() => {
      this.modalTarget.querySelector('.modal-backdrop')?.classList.add('opacity-100')
      this.modalTarget.querySelector('.modal-content')?.classList.add('scale-100', 'opacity-100')
    })
    
    document.body.style.overflow = 'hidden'
  }

  // Close modal
  closeModal() {
    if (!this.hasModalTarget) return
    
    const backdrop = this.modalTarget.querySelector('.modal-backdrop')
    const content = this.modalTarget.querySelector('.modal-content')
    
    backdrop?.classList.remove('opacity-100')
    content?.classList.remove('scale-100', 'opacity-100')
    
    setTimeout(() => {
      this.modalTarget.classList.add('hidden')
      this.modalTarget.classList.remove('flex')
      document.body.style.overflow = ''
    }, 300)
  }

  // Load user's wishlist collections
  async loadCollections() {
    try {
      const response = await fetch('/wishlists/collections', {
        headers: {
          'Accept': 'application/json'
        }
      })
      
      if (!response.ok) throw new Error('Failed to load collections')
      
      const collections = await response.json()
      this.renderCollections(collections)
      
    } catch (error) {
      console.error('Load collections error:', error)
      this.renderCollectionsError()
    }
  }

  // Render collections list
  renderCollections(collections) {
    if (!this.hasCollectionListTarget) return
    
    if (collections.length === 0) {
      this.collectionListTarget.innerHTML = `
        <div class="text-center py-8 text-gray-500">
          <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                  d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"/>
          </svg>
          <p>No collections yet</p>
          <p class="text-sm">Create your first collection below</p>
        </div>
      `
      return
    }
    
    this.collectionListTarget.innerHTML = `
      <div class="space-y-2">
        ${collections.map(collection => this.renderCollectionItem(collection)).join('')}
      </div>
    `
  }

  renderCollectionItem(collection) {
    return `
      <button class="w-full flex items-center justify-between p-4 rounded-lg border-2 
                   border-gray-200 hover:border-spirit-primary transition-all duration-200 group"
              data-action="click->wishlist-manager#addToCollection"
              data-collection-id="${collection.id}">
        <div class="flex items-center space-x-3">
          <div class="w-12 h-12 rounded-lg bg-gradient-to-br from-spirit-primary to-spirit-secondary 
                    flex items-center justify-center text-white font-bold">
            ${collection.icon || '❤️'}
          </div>
          <div class="text-left">
            <h4 class="font-semibold text-gray-900 group-hover:text-spirit-primary transition-colors">
              ${collection.name}
            </h4>
            <p class="text-sm text-gray-500">${collection.item_count} items</p>
          </div>
        </div>
        
        <svg class="w-5 h-5 text-gray-400 group-hover:text-spirit-primary transition-colors" 
             fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
        </svg>
      </button>
    `
  }

  renderCollectionsError() {
    if (!this.hasCollectionListTarget) return
    
    this.collectionListTarget.innerHTML = `
      <div class="text-center py-8">
        <svg class="w-16 h-16 mx-auto mb-4 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
        <p class="text-gray-700 mb-4">Failed to load collections</p>
        <button class="spirit-button" data-action="click->wishlist-manager#loadCollections">
          Try Again
        </button>
      </div>
    `
  }

  // Add to specific collection
  async addToCollection(event) {
    const collectionId = event.currentTarget.dataset.collectionId
    
    try {
      await this.addToWishlist(this.productIdValue, collectionId)
      this.closeModal()
    } catch (error) {
      console.error('Add to collection error:', error)
    }
  }

  // Create new collection
  async createCollection(event) {
    event.preventDefault()
    
    const form = event.currentTarget
    const formData = new FormData(form)
    const name = formData.get('name')
    const icon = formData.get('icon') || '❤️'
    const isPublic = formData.get('is_public') === 'on'
    
    try {
      const response = await fetch('/wishlists/collections', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({
          collection: {
            name,
            icon,
            is_public: isPublic
          }
        })
      })
      
      if (!response.ok) throw new Error('Failed to create collection')
      
      const collection = await response.json()
      
      // Add item to new collection
      await this.addToWishlist(this.productIdValue, collection.id)
      
      form.reset()
      this.closeModal()
      this.showSuccessNotification(`Collection "${name}" created!`)
      
    } catch (error) {
      console.error('Create collection error:', error)
      this.showErrorNotification('Failed to create collection')
    }
  }

  // Share wishlist
  async shareWishlist(event) {
    event.preventDefault()
    
    const shareUrl = window.location.origin + '/wishlist'
    
    if (navigator.share) {
      try {
        await navigator.share({
          title: 'My Wishlist',
          text: 'Check out my wishlist on The Final Market!',
          url: shareUrl
        })
        
        this.showSuccessNotification('Wishlist shared!')
      } catch (error) {
        if (error.name !== 'AbortError') {
          console.error('Share error:', error)
        }
      }
    } else {
      // Fallback: Copy to clipboard
      try {
        await navigator.clipboard.writeText(shareUrl)
        this.showSuccessNotification('Link copied to clipboard!')
      } catch (error) {
        console.error('Clipboard error:', error)
        this.showErrorNotification('Failed to copy link')
      }
    }
  }

  // Move all items to cart
  async moveAllToCart(event) {
    event.preventDefault()
    
    if (!confirm('Add all wishlist items to your cart?')) {
      return
    }
    
    try {
      const response = await fetch('/wishlist/move_all_to_cart', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': this.getCSRFToken()
        }
      })
      
      if (!response.ok) throw new Error('Failed to move items')
      
      const data = await response.json()
      
      this.showSuccessNotification(`${data.count} items added to cart!`)
      
      // Refresh page to show updated wishlist
      setTimeout(() => window.location.reload(), 1500)
      
    } catch (error) {
      console.error('Move to cart error:', error)
      this.showErrorNotification('Failed to add items to cart')
    }
  }

  // Create modal if it doesn't exist
  createModal() {
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 z-50 hidden items-center justify-center p-4'
    modal.dataset.wishlistManagerTarget = 'modal'
    
    modal.innerHTML = `
      <div class="modal-backdrop absolute inset-0 bg-black/60 backdrop-blur-sm transition-opacity duration-300 opacity-0"
           data-action="click->wishlist-manager#closeModal"></div>
      
      <div class="modal-content relative w-full max-w-md bg-white rounded-2xl shadow-2xl 
                  transform transition-all duration-300 scale-95 opacity-0 max-h-[80vh] overflow-hidden">
        
        <div class="flex items-center justify-between p-6 border-b border-gray-200">
          <h2 class="text-2xl font-bold text-spirit-dark">Add to Collection</h2>
          <button class="p-2 hover:bg-gray-100 rounded-full transition-colors"
                  data-action="click->wishlist-manager#closeModal">
            <svg class="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
        
        <div class="p-6 overflow-y-auto max-h-96" data-wishlist-manager-target="collectionList">
          <div class="flex items-center justify-center py-8">
            <div class="spirit-loader"></div>
          </div>
        </div>
        
        <div class="p-6 border-t border-gray-200 bg-gray-50">
          <form data-action="submit->wishlist-manager#createCollection" 
                data-wishlist-manager-target="createForm">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">Create New Collection</h3>
            
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Collection Name</label>
                <input type="text" name="name" required
                     class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-spirit-primary focus:border-transparent"
                     placeholder="e.g., Summer Favorites">
              </div>
              
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Icon (optional)</label>
                <input type="text" name="icon" maxlength="2"
                     class="w-20 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-spirit-primary focus:border-transparent text-center text-2xl"
                     placeholder="❤️">
              </div>
              
              <div class="flex items-center">
                <input type="checkbox" name="is_public" id="is_public"
                     class="w-4 h-4 text-spirit-primary border-gray-300 rounded focus:ring-spirit-primary">
                <label for="is_public" class="ml-2 text-sm text-gray-700">
                  Make this collection public
                </label>
              </div>
              
              <button type="submit" class="w-full spirit-button py-3">
                Create Collection
              </button>
            </div>
          </form>
        </div>
      </div>
    `
    
    document.body.appendChild(modal)
    this.modalTarget = modal
  }

  // Update button visual state
  updateButtonState() {
    if (this.hasIconTarget) {
      this.iconTargets.forEach(icon => {
        if (this.inWishlistValue) {
          icon.classList.add('text-red-500', 'fill-current')
          icon.classList.remove('text-gray-400')
        } else {
          icon.classList.remove('text-red-500', 'fill-current')
          icon.classList.add('text-gray-400')
        }
      })
    }
    
    if (this.hasButtonTarget) {
      this.buttonTargets.forEach(button => {
        const text = button.querySelector('.button-text')
        if (text) {
          text.textContent = this.inWishlistValue ? 'In Wishlist' : 'Add to Wishlist'
        }
      })
    }
  }

  // Update wishlist count
  updateCount(count) {
    if (this.hasCountTarget) {
      this.countTargets.forEach(target => {
        target.textContent = count
        
        // Pulse animation
        target.classList.add('animate-pulse')
        setTimeout(() => target.classList.remove('animate-pulse'), 600)
      })
    }
  }

  // Start animation
  startAnimation() {
    if (this.hasIconTarget) {
      this.iconTargets.forEach(icon => {
        icon.classList.add('animate-bounce')
        setTimeout(() => icon.classList.remove('animate-bounce'), 600)
      })
    }
  }

  // Play heart animation
  playHeartAnimation() {
    // Create floating hearts
    for (let i = 0; i < 3; i++) {
      setTimeout(() => this.createFloatingHeart(), i * 150)
    }
  }

  createFloatingHeart() {
    if (!this.hasIconTarget) return
    
    const icon = this.iconTargets[0]
    const rect = icon.getBoundingClientRect()
    
    const heart = document.createElement('div')
    heart.innerHTML = '❤️'
    heart.style.position = 'fixed'
    heart.style.left = rect.left + rect.width / 2 + 'px'
    heart.style.top = rect.top + 'px'
    heart.style.fontSize = '20px'
    heart.style.zIndex = '9999'
    heart.style.pointerEvents = 'none'
    heart.style.transition = 'all 1s ease-out'
    
    document.body.appendChild(heart)
    
    requestAnimationFrame(() => {
      heart.style.transform = `translateY(-100px) translateX(${Math.random() * 60 - 30}px) scale(0)`
      heart.style.opacity = '0'
    })
    
    setTimeout(() => heart.remove(), 1000)
  }

  // Utility functions
  getCSRFToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

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

  trackWishlistAdd(productId) {
    if (window.gtag) {
      window.gtag('event', 'add_to_wishlist', {
        event_category: 'ecommerce',
        product_id: productId
      })
    }
  }

  trackWishlistRemove(productId) {
    if (window.gtag) {
      window.gtag('event', 'remove_from_wishlist', {
        event_category: 'ecommerce',
        product_id: productId
      })
    }
  }
}