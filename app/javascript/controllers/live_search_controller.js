import { Controller } from "@hotwired/stimulus"

// Live Search with Autocomplete and Suggestions
export default class extends Controller {
  static targets = [
    "input",
    "results",
    "spinner",
    "recentSearches",
    "suggestions"
  ]

  static values = {
    url: String,
    minChars: { type: Number, default: 2 },
    debounceDelay: { type: Number, default: 300 }
  }

  connect() {
    this.boundSearch = this.debounce(this.search.bind(this), this.debounceDelayValue)
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
    this.loadRecentSearches()
  }

  disconnect() {
    document.removeEventListener('click', this.boundHandleClickOutside)
  }

  // Handle input changes
  search(event) {
    const query = this.inputTarget.value.trim()
    
    if (query.length === 0) {
      this.showRecentSearches()
      return
    }
    
    if (query.length < this.minCharsValue) {
      this.hideResults()
      return
    }
    
    this.performSearch(query)
  }

  // Perform search request
  async performSearch(query) {
    this.showSpinner()
    
    try {
      const url = new URL(this.urlValue || '/search/suggestions', window.location.origin)
      url.searchParams.set('q', query)
      
      const response = await fetch(url, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (!response.ok) throw new Error('Search failed')
      
      const data = await response.json()
      this.renderResults(data)
      
    } catch (error) {
      console.error('Search error:', error)
      this.renderError()
    } finally {
      this.hideSpinner()
    }
  }

  // Render search results
  renderResults(data) {
    if (!this.hasResultsTarget) return
    
    const { products, categories, suggestions, total } = data
    
    if (total === 0) {
      this.renderNoResults()
      return
    }
    
    let html = '<div class="live-search-results">'
    
    // Products
    if (products && products.length > 0) {
      html += `
        <div class="search-section">
          <div class="search-section-header">
            <span class="text-sm font-semibold text-gray-700">Products</span>
          </div>
          <div class="space-y-1">
            ${products.map(product => this.renderProductItem(product)).join('')}
          </div>
        </div>
      `
    }
    
    // Categories
    if (categories && categories.length > 0) {
      html += `
        <div class="search-section">
          <div class="search-section-header">
            <span class="text-sm font-semibold text-gray-700">Categories</span>
          </div>
          <div class="space-y-1">
            ${categories.map(category => this.renderCategoryItem(category)).join('')}
          </div>
        </div>
      `
    }
    
    // Suggestions
    if (suggestions && suggestions.length > 0) {
      html += `
        <div class="search-section">
          <div class="search-section-header">
            <span class="text-sm font-semibold text-gray-700">Suggestions</span>
          </div>
          <div class="space-y-1">
            ${suggestions.map(suggestion => this.renderSuggestionItem(suggestion)).join('')}
          </div>
        </div>
      `
    }
    
    // View all results link
    html += `
      <div class="search-section border-t">
        <a href="/items?query=${encodeURIComponent(this.inputTarget.value)}" 
           class="block p-3 text-center text-spirit-primary hover:bg-spirit-light font-medium transition-colors">
          View all ${total} results →
        </a>
      </div>
    `
    
    html += '</div>'
    
    this.resultsTarget.innerHTML = html
    this.showResults()
  }

  renderProductItem(product) {
    return `
      <a href="${product.url}" 
         class="flex items-center space-x-3 p-2 rounded-lg hover:bg-spirit-light/50 transition-colors"
         data-action="click->live-search#saveSearch">
        <div class="w-12 h-12 flex-shrink-0">
          <img src="${product.image_url}" 
               alt="${product.name}"
               class="w-full h-full object-cover rounded">
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium text-gray-900 truncate">${product.name}</p>
          <p class="text-sm text-spirit-primary font-semibold">${product.formatted_price}</p>
        </div>
      </a>
    `
  }

  renderCategoryItem(category) {
    return `
      <a href="${category.url}" 
         class="flex items-center space-x-3 p-2 rounded-lg hover:bg-spirit-light/50 transition-colors"
         data-action="click->live-search#saveSearch">
        <div class="w-8 h-8 flex-shrink-0 flex items-center justify-center bg-spirit-light rounded-full">
          <svg class="w-4 h-4 text-spirit-primary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                  d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"/>
          </svg>
        </div>
        <div class="flex-1 min-w-0">
          <p class="text-sm font-medium text-gray-900">${category.name}</p>
          <p class="text-xs text-gray-500">${category.products_count} products</p>
        </div>
      </a>
    `
  }

  renderSuggestionItem(suggestion) {
    return `
      <button type="button"
              class="w-full flex items-center space-x-3 p-2 rounded-lg hover:bg-spirit-light/50 transition-colors text-left"
              data-action="click->live-search#applySuggestion"
              data-suggestion="${suggestion}">
        <div class="w-8 h-8 flex-shrink-0 flex items-center justify-center">
          <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                  d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
          </svg>
        </div>
        <p class="text-sm text-gray-700">${suggestion}</p>
      </button>
    `
  }

  renderNoResults() {
    this.resultsTarget.innerHTML = `
      <div class="live-search-results">
        <div class="p-8 text-center">
          <svg class="w-16 h-16 mx-auto text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                  d="M9.172 16.172a4 4 0 015.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          <p class="text-gray-600">No results found</p>
          <p class="text-sm text-gray-500 mt-2">Try different keywords</p>
        </div>
      </div>
    `
    this.showResults()
  }

  renderError() {
    this.resultsTarget.innerHTML = `
      <div class="live-search-results">
        <div class="p-8 text-center">
          <svg class="w-16 h-16 mx-auto text-red-500 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                  d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          <p class="text-gray-600">Search failed</p>
          <p class="text-sm text-gray-500 mt-2">Please try again</p>
        </div>
      </div>
    `
    this.showResults()
  }

  // Show recent searches
  showRecentSearches() {
    const recent = this.getRecentSearches()
    
    if (recent.length === 0) {
      this.hideResults()
      return
    }
    
    const html = `
      <div class="live-search-results">
        <div class="search-section">
          <div class="search-section-header flex items-center justify-between">
            <span class="text-sm font-semibold text-gray-700">Recent Searches</span>
            <button class="text-xs text-spirit-primary hover:text-spirit-secondary"
                    data-action="click->live-search#clearRecentSearches">
              Clear
            </button>
          </div>
          <div class="space-y-1">
            ${recent.map(search => `
              <button type="button"
                      class="w-full flex items-center space-x-3 p-2 rounded-lg hover:bg-spirit-light/50 transition-colors text-left"
                      data-action="click->live-search#applySuggestion"
                      data-suggestion="${search}">
                <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                        d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
                <span class="text-sm text-gray-700">${search}</span>
              </button>
            `).join('')}
          </div>
        </div>
      </div>
    `
    
    this.resultsTarget.innerHTML = html
    this.showResults()
  }

  // Apply suggestion to input
  applySuggestion(event) {
    const suggestion = event.currentTarget.dataset.suggestion
    this.inputTarget.value = suggestion
    this.inputTarget.form?.submit()
  }

  // Save search to recent searches
  saveSearch() {
    const query = this.inputTarget.value.trim()
    if (!query) return
    
    let recent = this.getRecentSearches()
    
    // Remove if already exists
    recent = recent.filter(s => s !== query)
    
    // Add to beginning
    recent.unshift(query)
    
    // Keep only last 10
    recent = recent.slice(0, 10)
    
    localStorage.setItem('recent_searches', JSON.stringify(recent))
  }

  // Get recent searches from localStorage
  getRecentSearches() {
    try {
      const stored = localStorage.getItem('recent_searches')
      return stored ? JSON.parse(stored) : []
    } catch (error) {
      return []
    }
  }

  loadRecentSearches() {
    // Preload for faster display
    this.recentSearches = this.getRecentSearches()
  }

  // Clear recent searches
  clearRecentSearches() {
    localStorage.removeItem('recent_searches')
    this.recentSearches = []
    this.hideResults()
  }

  // Show/hide results
  showResults() {
    if (!this.hasResultsTarget) return
    
    this.resultsTarget.classList.remove('hidden')
    document.addEventListener('click', this.boundHandleClickOutside)
  }

  hideResults() {
    if (!this.hasResultsTarget) return
    
    this.resultsTarget.classList.add('hidden')
    document.removeEventListener('click', this.boundHandleClickOutside)
  }

  // Show/hide spinner
  showSpinner() {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.remove('hidden')
    }
  }

  hideSpinner() {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add('hidden')
    }
  }

  // Handle click outside
  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideResults()
    }
  }

  // Handle focus on input
  focus() {
    if (this.inputTarget.value.trim().length === 0) {
      this.showRecentSearches()
    } else {
      this.search()
    }
  }

  // Handle blur
  blur() {
    // Delay to allow click events on results
    setTimeout(() => {
      if (!this.element.contains(document.activeElement)) {
        this.hideResults()
      }
    }, 200)
  }

  // Utility: Debounce
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