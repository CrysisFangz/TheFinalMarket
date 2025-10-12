import { Controller } from "@hotwired/stimulus"

// Product Comparison Tool
// Allows side-by-side comparison of up to 4 products
export default class extends Controller {
  static targets = [
    "bar",
    "count",
    "list",
    "compareButton",
    "modal",
    "comparisonGrid"
  ]

  static values = {
    maxItems: { type: Number, default: 4 },
    url: String
  }

  connect() {
    this.comparedItems = this.loadFromStorage()
    this.updateUI()
  }

  // Add product to comparison
  async add(event) {
    event.preventDefault()
    
    const button = event.currentTarget
    const productId = button.dataset.productId || event.params?.productId
    const productName = button.dataset.productName
    const productImage = button.dataset.productImage
    const productPrice = button.dataset.productPrice
    
    // Check if already in comparison
    if (this.comparedItems.some(item => item.id === productId)) {
      this.showNotification('Product already in comparison', 'warning')
      return
    }
    
    // Check max limit
    if (this.comparedItems.length >= this.maxItemsValue) {
      this.showNotification(`Maximum ${this.maxItemsValue} products can be compared`, 'error')
      return
    }
    
    // Add to comparison
    const item = {
      id: productId,
      name: productName,
      image: productImage,
      price: productPrice
    }
    
    this.comparedItems.push(item)
    this.saveToStorage()
    this.updateUI()
    this.showComparisonBar()
    
    // Animate button
    button.classList.add('animate-bounce')
    setTimeout(() => button.classList.remove('animate-bounce'), 600)
    
    this.showNotification(`${productName} added to comparison`, 'success')
    
    // Track analytics
    this.trackComparison('add', productId)
  }

  // Remove product from comparison
  remove(event) {
    event.preventDefault()
    
    const productId = event.currentTarget.dataset.productId
    const itemIndex = this.comparedItems.findIndex(item => item.id === productId)
    
    if (itemIndex > -1) {
      const removedItem = this.comparedItems.splice(itemIndex, 1)[0]
      this.saveToStorage()
      this.updateUI()
      
      if (this.comparedItems.length === 0) {
        this.hideComparisonBar()
      }
      
      this.showNotification(`${removedItem.name} removed from comparison`, 'info')
      
      // Track analytics
      this.trackComparison('remove', productId)
    }
  }

  // Clear all comparisons
  clearAll() {
    if (this.comparedItems.length === 0) return
    
    if (!confirm('Remove all products from comparison?')) {
      return
    }
    
    this.comparedItems = []
    this.saveToStorage()
    this.updateUI()
    this.hideComparisonBar()
    
    this.showNotification('Comparison cleared', 'info')
    
    // Track analytics
    this.trackComparison('clear_all')
  }

  // Show comparison modal
  async showComparison() {
    if (this.comparedItems.length < 2) {
      this.showNotification('Add at least 2 products to compare', 'warning')
      return
    }
    
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
    
    document.body.style.overflow = 'hidden'
    
    // Load comparison data
    await this.loadComparisonData()
    
    // Track analytics
    this.trackComparison('view')
  }

  // Close comparison modal
  closeComparison() {
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

  // Load detailed comparison data
  async loadComparisonData() {
    if (!this.hasComparisonGridTarget) return
    
    const productIds = this.comparedItems.map(item => item.id)
    
    try {
      this.showLoadingState()
      
      const response = await fetch(`${this.urlValue}?product_ids=${productIds.join(',')}`, {
        headers: {
          'Accept': 'application/json'
        }
      })
      
      if (!response.ok) throw new Error('Failed to load comparison data')
      
      const data = await response.json()
      this.renderComparison(data)
      
    } catch (error) {
      console.error('Load comparison error:', error)
      this.renderComparisonError()
    }
  }

  // Render comparison table
  renderComparison(data) {
    if (!this.hasComparisonGridTarget) return
    
    const { products, attributes } = data
    
    this.comparisonGridTarget.innerHTML = `
      <div class="overflow-x-auto">
        <table class="w-full border-collapse">
          <thead>
            <tr class="bg-spirit-light">
              <th class="p-4 text-left font-semibold text-gray-700 sticky left-0 bg-spirit-light z-10">
                Feature
              </th>
              ${products.map(product => `
                <th class="p-4 text-center min-w-[200px]">
                  <div class="flex flex-col items-center space-y-2">
                    <img src="${product.image_url}" alt="${product.name}" 
                         class="w-24 h-24 object-cover rounded-lg">
                    <h3 class="font-semibold text-gray-900">${product.name}</h3>
                    <p class="text-lg font-bold text-spirit-primary">${product.formatted_price}</p>
                    <button class="text-sm text-red-500 hover:text-red-700"
                            data-action="click->product-comparison#remove"
                            data-product-id="${product.id}">
                      Remove
                    </button>
                  </div>
                </th>
              `).join('')}
            </tr>
          </thead>
          <tbody>
            ${attributes.map((attr, index) => `
              <tr class="${index % 2 === 0 ? 'bg-white' : 'bg-gray-50'}">
                <td class="p-4 font-medium text-gray-700 sticky left-0 ${index % 2 === 0 ? 'bg-white' : 'bg-gray-50'} z-10 border-r border-gray-200">
                  ${attr.label}
                </td>
                ${products.map(product => `
                  <td class="p-4 text-center">
                    ${this.renderAttributeValue(product[attr.key], attr.type)}
                  </td>
                `).join('')}
              </tr>
            `).join('')}
            
            <tr class="bg-spirit-light font-semibold">
              <td class="p-4 sticky left-0 bg-spirit-light z-10">Actions</td>
              ${products.map(product => `
                <td class="p-4 text-center">
                  <div class="flex flex-col space-y-2">
                    <button class="spirit-button w-full"
                            data-action="click->enhanced-cart#addItem"
                            data-product-id="${product.id}">
                      Add to Cart
                    </button>
                    <a href="${product.url}" class="text-spirit-primary hover:text-spirit-secondary text-sm">
                      View Details →
                    </a>
                  </div>
                </td>
              `).join('')}
            </tr>
          </tbody>
        </table>
      </div>
    `
    
    this.hideLoadingState()
  }

  // Render attribute value based on type
  renderAttributeValue(value, type) {
    if (!value && value !== 0) {
      return '<span class="text-gray-400">N/A</span>'
    }
    
    switch (type) {
      case 'boolean':
        return value ? 
          '<svg class="w-6 h-6 text-green-500 mx-auto" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/></svg>' :
          '<svg class="w-6 h-6 text-red-500 mx-auto" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/></svg>'
      
      case 'rating':
        return this.renderStars(value)
      
      case 'price':
        return `<span class="font-bold">${this.formatCurrency(value)}</span>`
      
      case 'array':
        return Array.isArray(value) ? value.join(', ') : value
      
      default:
        return value
    }
  }

  renderStars(rating) {
    const fullStars = Math.floor(rating)
    const hasHalfStar = rating % 1 >= 0.5
    const emptyStars = 5 - fullStars - (hasHalfStar ? 1 : 0)
    
    return `
      <div class="flex justify-center text-yellow-400">
        ${'★'.repeat(fullStars)}
        ${hasHalfStar ? '½' : ''}
        ${'☆'.repeat(emptyStars)}
      </div>
    `
  }

  renderComparisonError() {
    if (!this.hasComparisonGridTarget) return
    
    this.comparisonGridTarget.innerHTML = `
      <div class="flex flex-col items-center justify-center py-12 space-y-4">
        <svg class="w-16 h-16 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
        <h3 class="text-xl font-bold text-gray-900">Failed to Load Comparison</h3>
        <p class="text-gray-600">Please try again</p>
        <button class="spirit-button" data-action="click->product-comparison#loadComparisonData">
          Retry
        </button>
      </div>
    `
    
    this.hideLoadingState()
  }

  // Update UI elements
  updateUI() {
    this.updateCount()
    this.updateList()
    this.updateCompareButton()
  }

  updateCount() {
    if (this.hasCountTarget) {
      this.countTargets.forEach(target => {
        target.textContent = this.comparedItems.length
        
        if (this.comparedItems.length > 0) {
          target.classList.remove('hidden')
        } else {
          target.classList.add('hidden')
        }
      })
    }
  }

  updateList() {
    if (!this.hasListTarget) return
    
    if (this.comparedItems.length === 0) {
      this.listTarget.innerHTML = `
        <div class="text-center py-4 text-gray-500 text-sm">
          No products to compare
        </div>
      `
      return
    }
    
    this.listTarget.innerHTML = this.comparedItems.map(item => `
      <div class="flex items-center justify-between p-2 bg-white rounded-lg shadow-sm group hover:shadow-md transition-all">
        <div class="flex items-center space-x-2 flex-1 min-w-0">
          <img src="${item.image}" alt="${item.name}" class="w-12 h-12 object-cover rounded">
          <div class="flex-1 min-w-0">
            <p class="font-medium text-sm text-gray-900 truncate">${item.name}</p>
            <p class="text-xs text-gray-500">${item.price}</p>
          </div>
        </div>
        <button class="p-2 text-gray-400 hover:text-red-500 transition-colors opacity-0 group-hover:opacity-100"
                data-action="click->product-comparison#remove"
                data-product-id="${item.id}">
          <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"/>
          </svg>
        </button>
      </div>
    `).join('')
  }

  updateCompareButton() {
    if (this.hasCompareButtonTarget) {
      this.compareButtonTargets.forEach(button => {
        if (this.comparedItems.length < 2) {
          button.disabled = true
          button.classList.add('opacity-50', 'cursor-not-allowed')
        } else {
          button.disabled = false
          button.classList.remove('opacity-50', 'cursor-not-allowed')
        }
      })
    }
  }

  // Show/hide comparison bar
  showComparisonBar() {
    if (this.hasBarTarget) {
      this.barTarget.classList.remove('translate-y-full')
      this.barTarget.classList.add('translate-y-0')
    }
  }

  hideComparisonBar() {
    if (this.hasBarTarget) {
      this.barTarget.classList.add('translate-y-full')
      this.barTarget.classList.remove('translate-y-0')
    }
  }

  // Create modal
  createModal() {
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 z-50 hidden items-center justify-center p-4'
    modal.dataset.productComparisonTarget = 'modal'
    
    modal.innerHTML = `
      <div class="modal-backdrop absolute inset-0 bg-black/60 backdrop-blur-sm transition-opacity duration-300 opacity-0"
           data-action="click->product-comparison#closeComparison"></div>
      
      <div class="modal-content relative w-full max-w-7xl max-h-[90vh] bg-white rounded-2xl shadow-2xl 
                  transform transition-all duration-300 scale-95 opacity-0 overflow-hidden flex flex-col">
        
        <div class="flex items-center justify-between p-6 border-b border-gray-200 flex-shrink-0">
          <h2 class="text-2xl font-bold text-spirit-dark">Product Comparison</h2>
          <button class="p-2 hover:bg-gray-100 rounded-full transition-colors"
                  data-action="click->product-comparison#closeComparison">
            <svg class="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
        
        <div class="flex-1 overflow-y-auto" data-product-comparison-target="comparisonGrid">
          <div class="flex items-center justify-center py-12">
            <div class="spirit-loader"></div>
          </div>
        </div>
      </div>
    `
    
    document.body.appendChild(modal)
    this.modalTarget = modal
  }

  // Loading states
  showLoadingState() {
    if (this.hasComparisonGridTarget) {
      this.comparisonGridTarget.innerHTML = `
        <div class="flex items-center justify-center py-12">
          <div class="spirit-loader"></div>
        </div>
      `
    }
  }

  hideLoadingState() {
    // Loading state is replaced by content
  }

  // Storage management
  saveToStorage() {
    localStorage.setItem('compared_products', JSON.stringify(this.comparedItems))
  }

  loadFromStorage() {
    const stored = localStorage.getItem('compared_products')
    return stored ? JSON.parse(stored) : []
  }

  // Utility functions
  formatCurrency(amount) {
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(amount)
  }

  showNotification(message, type = 'info') {
    if (window.Toastify) {
      const colors = {
        success: 'linear-gradient(135deg, #10b981, #059669)',
        error: 'linear-gradient(135deg, #ef4444, #dc2626)',
        warning: 'linear-gradient(135deg, #f59e0b, #d97706)',
        info: 'linear-gradient(135deg, #6B4FA9, #9C7BE3)'
      }
      
      Toastify({
        text: message,
        duration: 3000,
        gravity: "top",
        position: "right",
        backgroundColor: colors[type] || colors.info,
        stopOnFocus: true
      }).showToast()
    }
  }

  trackComparison(action, productId = null) {
    if (window.gtag) {
      window.gtag('event', 'product_comparison', {
        event_category: 'ecommerce',
        action: action,
        product_id: productId,
        comparison_count: this.comparedItems.length
      })
    }
  }
}