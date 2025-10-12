import { Controller } from "@hotwired/stimulus"

// Advanced Quick View Controller for Product Previews
// Provides instant product preview without page navigation
export default class extends Controller {
  static targets = ["modal", "content", "spinner"]
  static values = {
    productId: Number,
    url: String
  }

  connect() {
    this.boundClose = this.close.bind(this)
    this.boundEscapeHandler = this.handleEscape.bind(this)
    
    // Prefetch on hover for instant loading
    this.element.addEventListener('mouseenter', () => this.prefetch(), { once: true })
  }

  disconnect() {
    document.removeEventListener('keydown', this.boundEscapeHandler)
  }

  // Prefetch product data on hover for instant display
  async prefetch() {
    if (this.prefetchedData) return
    
    try {
      const response = await fetch(`${this.urlValue}?format=json`, {
        headers: { 'Accept': 'application/json' }
      })
      this.prefetchedData = await response.json()
    } catch (error) {
      console.warn('Prefetch failed:', error)
    }
  }

  // Open modal with smooth animation
  async open(event) {
    event?.preventDefault()
    
    // Show modal immediately
    this.showModal()
    
    // Use prefetched data or fetch new
    if (this.prefetchedData) {
      this.renderContent(this.prefetchedData)
    } else {
      this.showSpinner()
      await this.fetchAndRender()
    }
    
    // Enable keyboard navigation
    document.addEventListener('keydown', this.boundEscapeHandler)
    
    // Track analytics
    this.trackView()
  }

  showModal() {
    if (!this.hasModalTarget) {
      this.createModal()
    }
    
    this.modalTarget.classList.remove('hidden')
    this.modalTarget.classList.add('flex')
    
    // Animate in
    requestAnimationFrame(() => {
      this.modalTarget.querySelector('.modal-backdrop')?.classList.add('opacity-100')
      this.modalTarget.querySelector('.modal-content')?.classList.add('scale-100', 'opacity-100')
    })
    
    // Prevent body scroll
    document.body.style.overflow = 'hidden'
  }

  createModal() {
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 z-50 hidden items-center justify-center p-4'
    modal.dataset.quickViewTarget = 'modal'
    
    modal.innerHTML = `
      <div class="modal-backdrop absolute inset-0 bg-black/60 backdrop-blur-sm transition-opacity duration-300 opacity-0"
           data-action="click->quick-view#close"></div>
      
      <div class="modal-content relative w-full max-w-6xl max-h-[90vh] bg-white rounded-2xl shadow-2xl 
                  transform transition-all duration-300 scale-95 opacity-0 overflow-hidden">
        
        <!-- Close Button -->
        <button class="absolute top-4 right-4 z-10 p-2 rounded-full bg-white/90 hover:bg-white 
                       shadow-lg transition-all duration-200 hover:scale-110 group"
                data-action="click->quick-view#close">
          <svg class="w-6 h-6 text-gray-600 group-hover:text-gray-900" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
        
        <!-- Loading Spinner -->
        <div class="absolute inset-0 flex items-center justify-center bg-white/95" data-quick-view-target="spinner">
          <div class="flex flex-col items-center space-y-4">
            <div class="spirit-loader w-16 h-16"></div>
            <p class="text-spirit-primary font-medium">Loading product details...</p>
          </div>
        </div>
        
        <!-- Content Container -->
        <div class="overflow-y-auto max-h-[90vh] hidden" data-quick-view-target="content">
          <!-- Dynamic content loads here -->
        </div>
      </div>
    `
    
    document.body.appendChild(modal)
    this.modalTarget = modal
  }

  async fetchAndRender() {
    try {
      const response = await fetch(`${this.urlValue}?format=json`, {
        headers: { 'Accept': 'application/json' }
      })
      
      if (!response.ok) throw new Error('Failed to load product')
      
      const data = await response.json()
      this.renderContent(data)
    } catch (error) {
      this.renderError(error)
    }
  }

  renderContent(data) {
    this.hideSpinner()
    
    const { product, variants, reviews } = data
    const averageRating = reviews?.average_rating || 0
    const reviewCount = reviews?.count || 0
    
    this.contentTarget.innerHTML = `
      <div class="grid md:grid-cols-2 gap-8 p-8">
        
        <!-- Image Gallery -->
        <div class="space-y-4">
          <div class="aspect-square bg-gradient-to-br from-spirit-light to-white rounded-xl overflow-hidden 
                      border-2 border-spirit-light group relative">
            <img src="${product.image_url}" 
                 alt="${product.name}"
                 class="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110">
            
            ${product.badges ? this.renderBadges(product.badges) : ''}
          </div>
          
          ${product.additional_images?.length ? this.renderThumbnails(product.additional_images) : ''}
        </div>
        
        <!-- Product Details -->
        <div class="flex flex-col space-y-6">
          
          <!-- Header -->
          <div class="space-y-3">
            <div class="flex items-start justify-between">
              <h2 class="text-3xl font-bold text-spirit-dark">${product.name}</h2>
              ${this.renderWishlistButton(product.id)}
            </div>
            
            <!-- Rating -->
            ${reviewCount > 0 ? `
              <div class="flex items-center space-x-2">
                ${this.renderStars(averageRating)}
                <span class="text-sm text-gray-600">(${reviewCount} reviews)</span>
              </div>
            ` : ''}
            
            <!-- Price -->
            <div class="flex items-baseline space-x-3">
              <span class="text-4xl font-bold text-spirit-primary">${product.formatted_price}</span>
              ${product.original_price ? `
                <span class="text-xl text-gray-400 line-through">${product.formatted_original_price}</span>
                <span class="px-3 py-1 bg-red-500 text-white rounded-full text-sm font-bold">
                  ${product.discount_percentage}% OFF
                </span>
              ` : ''}
            </div>
          </div>
          
          <!-- Description -->
          <div class="prose prose-sm max-w-none">
            <p class="text-gray-600 leading-relaxed">${product.description}</p>
          </div>
          
          <!-- Variants -->
          ${variants?.length ? this.renderVariants(variants) : ''}
          
          <!-- Stock Status -->
          <div class="flex items-center space-x-2">
            ${product.in_stock ? `
              <div class="flex items-center space-x-2">
                <div class="w-3 h-3 bg-green-500 rounded-full animate-pulse"></div>
                <span class="text-green-600 font-medium">In Stock (${product.stock_quantity} available)</span>
              </div>
            ` : `
              <div class="flex items-center space-x-2">
                <div class="w-3 h-3 bg-red-500 rounded-full"></div>
                <span class="text-red-600 font-medium">Out of Stock</span>
              </div>
            `}
          </div>
          
          <!-- Features -->
          ${product.features?.length ? this.renderFeatures(product.features) : ''}
          
          <!-- Actions -->
          <div class="space-y-3 pt-4 border-t border-gray-200">
            <div class="flex space-x-3">
              <button class="flex-1 spirit-button py-4 text-lg font-bold
                           ${!product.in_stock ? 'opacity-50 cursor-not-allowed' : ''}"
                      data-action="click->cart#addItem"
                      data-product-id="${product.id}"
                      ${!product.in_stock ? 'disabled' : ''}>
                <svg class="inline w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                        d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z"/>
                </svg>
                ${product.in_stock ? 'Add to Cart' : 'Out of Stock'}
              </button>
              
              <button class="px-6 py-4 border-2 border-spirit-primary text-spirit-primary rounded-lg
                           font-bold hover:bg-spirit-light transition-all duration-200"
                      data-action="click->comparisons#add"
                      data-product-id="${product.id}">
                <svg class="inline w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                        d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
                </svg>
              </button>
            </div>
            
            <a href="${product.url}" 
               class="block text-center py-3 text-spirit-primary hover:text-spirit-secondary 
                      font-medium transition-colors duration-200">
              View Full Details →
            </a>
          </div>
          
          <!-- Seller Info -->
          ${product.seller ? this.renderSellerInfo(product.seller) : ''}
        </div>
      </div>
      
      <!-- Reviews Preview -->
      ${reviews?.items?.length ? this.renderReviewsPreview(reviews.items) : ''}
    `
    
    this.contentTarget.classList.remove('hidden')
  }

  renderBadges(badges) {
    return `
      <div class="absolute top-4 left-4 space-y-2">
        ${badges.map(badge => `
          <span class="block px-3 py-1 rounded-full text-xs font-bold text-white ${badge.color}">
            ${badge.text}
          </span>
        `).join('')}
      </div>
    `
  }

  renderThumbnails(images) {
    return `
      <div class="flex space-x-2 overflow-x-auto">
        ${images.map(img => `
          <img src="${img.thumbnail_url}" 
               alt="Product thumbnail"
               class="w-20 h-20 rounded-lg object-cover cursor-pointer border-2 border-transparent
                      hover:border-spirit-primary transition-all duration-200"
               data-action="click->gallery#changeImage"
               data-full-url="${img.url}">
        `).join('')}
      </div>
    `
  }

  renderStars(rating) {
    const fullStars = Math.floor(rating)
    const hasHalfStar = rating % 1 >= 0.5
    const emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0)
    
    return `
      <div class="flex items-center text-yellow-400">
        ${'★'.repeat(fullStars)}
        ${hasHalfStar ? '½' : ''}
        ${'☆'.repeat(emptyStars)}
      </div>
    `
  }

  renderWishlistButton(productId) {
    return `
      <button class="p-3 rounded-full hover:bg-spirit-light transition-all duration-200 group"
              data-action="click->wishlist#toggle"
              data-product-id="${productId}">
        <svg class="w-6 h-6 text-gray-400 group-hover:text-red-500 transition-colors duration-200" 
             fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"/>
        </svg>
      </button>
    `
  }

  renderVariants(variants) {
    return `
      <div class="space-y-3">
        <label class="text-sm font-semibold text-gray-700">Select Variant</label>
        <div class="grid grid-cols-3 gap-2">
          ${variants.map(variant => `
            <button class="px-4 py-3 border-2 border-gray-200 rounded-lg hover:border-spirit-primary
                         transition-all duration-200 text-sm font-medium
                         ${!variant.in_stock ? 'opacity-50 cursor-not-allowed' : ''}"
                    data-action="click->variants#select"
                    data-variant-id="${variant.id}"
                    ${!variant.in_stock ? 'disabled' : ''}>
              ${variant.name}
              ${variant.price_difference ? `<br><span class="text-xs text-gray-500">+${variant.price_difference}</span>` : ''}
            </button>
          `).join('')}
        </div>
      </div>
    `
  }

  renderFeatures(features) {
    return `
      <div class="space-y-2">
        <h3 class="text-sm font-semibold text-gray-700">Key Features</h3>
        <ul class="space-y-2">
          ${features.map(feature => `
            <li class="flex items-start space-x-2">
              <svg class="w-5 h-5 text-green-500 mt-0.5 flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
              </svg>
              <span class="text-gray-600">${feature}</span>
            </li>
          `).join('')}
        </ul>
      </div>
    `
  }

  renderSellerInfo(seller) {
    return `
      <div class="flex items-center space-x-4 p-4 bg-spirit-light/30 rounded-lg">
        <img src="${seller.avatar_url}" alt="${seller.name}" class="w-12 h-12 rounded-full">
        <div class="flex-1">
          <p class="font-semibold text-gray-900">${seller.name}</p>
          <div class="flex items-center space-x-2 text-sm text-gray-600">
            ${this.renderStars(seller.rating)}
            <span>(${seller.sales_count} sales)</span>
          </div>
        </div>
        <a href="${seller.profile_url}" class="text-spirit-primary hover:text-spirit-secondary font-medium">
          View Shop →
        </a>
      </div>
    `
  }

  renderReviewsPreview(reviews) {
    return `
      <div class="border-t border-gray-200 p-8 bg-gray-50">
        <h3 class="text-2xl font-bold text-spirit-dark mb-6">Customer Reviews</h3>
        <div class="space-y-4">
          ${reviews.slice(0, 3).map(review => `
            <div class="bg-white p-4 rounded-lg">
              <div class="flex items-center justify-between mb-2">
                <div class="flex items-center space-x-2">
                  <img src="${review.user.avatar_url}" alt="${review.user.name}" 
                       class="w-8 h-8 rounded-full">
                  <span class="font-medium text-gray-900">${review.user.name}</span>
                </div>
                ${this.renderStars(review.rating)}
              </div>
              <p class="text-gray-600 text-sm">${review.comment}</p>
              <p class="text-xs text-gray-400 mt-2">${review.created_at}</p>
            </div>
          `).join('')}
        </div>
      </div>
    `
  }

  showSpinner() {
    this.spinnerTarget.classList.remove('hidden')
  }

  hideSpinner() {
    this.spinnerTarget.classList.add('hidden')
  }

  renderError(error) {
    this.hideSpinner()
    this.contentTarget.innerHTML = `
      <div class="flex flex-col items-center justify-center p-12 space-y-4">
        <svg class="w-16 h-16 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
        <h3 class="text-xl font-bold text-gray-900">Failed to Load Product</h3>
        <p class="text-gray-600">Please try again or view the full product page</p>
        <button class="spirit-button" data-action="click->quick-view#close">Close</button>
      </div>
    `
    this.contentTarget.classList.remove('hidden')
  }

  close() {
    const backdrop = this.modalTarget.querySelector('.modal-backdrop')
    const content = this.modalTarget.querySelector('.modal-content')
    
    backdrop?.classList.remove('opacity-100')
    content?.classList.remove('scale-100', 'opacity-100')
    
    setTimeout(() => {
      this.modalTarget.classList.add('hidden')
      this.modalTarget.classList.remove('flex')
      document.body.style.overflow = ''
    }, 300)
    
    document.removeEventListener('keydown', this.boundEscapeHandler)
  }

  handleEscape(event) {
    if (event.key === 'Escape') {
      this.close()
    }
  }

  trackView() {
    // Send analytics event
    if (window.gtag) {
      window.gtag('event', 'quick_view', {
        product_id: this.productIdValue,
        product_url: this.urlValue
      })
    }
  }
}