import { Controller } from "@hotwired/stimulus"

// Advanced Multi-Faceted Filter System
// Provides real-time filtering with price ranges, categories, ratings, and more
export default class extends Controller {
  static targets = [
    "form",
    "results",
    "priceMin",
    "priceMax",
    "priceDisplay",
    "categoryCheckbox",
    "ratingButton",
    "sortSelect",
    "clearButton",
    "activeFilters",
    "resultCount",
    "loadingSpinner"
  ]

  static values = {
    url: String,
    debounceDelay: { type: Number, default: 300 }
  }

  connect() {
    this.filters = this.loadFiltersFromURL()
    this.applyFiltersToUI()
    this.setupPriceSlider()
    this.boundSearch = this.debounce(this.search.bind(this), this.debounceDelayValue)
    
    // Initial search if filters present
    if (Object.keys(this.filters).length > 0) {
      this.search()
    }
  }

  // Load filters from URL parameters
  loadFiltersFromURL() {
    const params = new URLSearchParams(window.location.search)
    const filters = {}
    
    for (const [key, value] of params.entries()) {
      if (key.startsWith('filter_')) {
        const filterKey = key.replace('filter_', '')
        if (filters[filterKey]) {
          filters[filterKey] = Array.isArray(filters[filterKey]) 
            ? [...filters[filterKey], value] 
            : [filters[filterKey], value]
        } else {
          filters[filterKey] = value
        }
      }
    }
    
    return filters
  }

  // Apply loaded filters to UI
  applyFiltersToUI() {
    // Price range
    if (this.filters.price_min && this.hasPriceMinTarget) {
      this.priceMinTarget.value = this.filters.price_min
    }
    if (this.filters.price_max && this.hasPriceMaxTarget) {
      this.priceMaxTarget.value = this.filters.price_max
    }
    
    // Categories
    if (this.filters.categories) {
      const categories = Array.isArray(this.filters.categories) 
        ? this.filters.categories 
        : [this.filters.categories]
      
      this.categoryCheckboxTargets.forEach(checkbox => {
        if (categories.includes(checkbox.value)) {
          checkbox.checked = true
        }
      })
    }
    
    // Rating
    if (this.filters.rating && this.hasRatingButtonTarget) {
      this.ratingButtonTargets.forEach(btn => {
        if (btn.dataset.rating === this.filters.rating) {
          btn.classList.add('active')
        }
      })
    }
    
    // Sort
    if (this.filters.sort && this.hasSortSelectTarget) {
      this.sortSelectTarget.value = this.filters.sort
    }
    
    this.updateActiveFiltersDisplay()
  }

  // Setup interactive price slider
  setupPriceSlider() {
    if (!this.hasPriceMinTarget || !this.hasPriceMaxTarget) return
    
    const updateDisplay = () => {
      if (this.hasPriceDisplayTarget) {
        const min = this.formatPrice(this.priceMinTarget.value)
        const max = this.formatPrice(this.priceMaxTarget.value)
        this.priceDisplayTarget.textContent = `${min} - ${max}`
      }
    }
    
    this.priceMinTarget.addEventListener('input', () => {
      // Ensure min doesn't exceed max
      if (parseInt(this.priceMinTarget.value) > parseInt(this.priceMaxTarget.value)) {
        this.priceMinTarget.value = this.priceMaxTarget.value
      }
      updateDisplay()
      this.boundSearch()
    })
    
    this.priceMaxTarget.addEventListener('input', () => {
      // Ensure max doesn't go below min
      if (parseInt(this.priceMaxTarget.value) < parseInt(this.priceMinTarget.value)) {
        this.priceMaxTarget.value = this.priceMinTarget.value
      }
      updateDisplay()
      this.boundSearch()
    })
    
    updateDisplay()
  }

  // Handle category filter change
  filterByCategory(event) {
    this.boundSearch()
  }

  // Handle rating filter
  filterByRating(event) {
    const rating = event.currentTarget.dataset.rating
    
    // Toggle active state
    this.ratingButtonTargets.forEach(btn => btn.classList.remove('active'))
    
    if (this.filters.rating === rating) {
      // Remove filter if clicking same rating
      delete this.filters.rating
    } else {
      // Set new rating filter
      this.filters.rating = rating
      event.currentTarget.classList.add('active')
    }
    
    this.search()
  }

  // Handle sort change
  sortResults(event) {
    this.filters.sort = event.target.value
    this.search()
  }

  // Gather all active filters
  gatherFilters() {
    const filters = { ...this.filters }
    
    // Price range
    if (this.hasPriceMinTarget && this.priceMinTarget.value) {
      filters.price_min = this.priceMinTarget.value
    }
    if (this.hasPriceMaxTarget && this.priceMaxTarget.value) {
      filters.price_max = this.priceMaxTarget.value
    }
    
    // Categories
    const selectedCategories = this.categoryCheckboxTargets
      .filter(checkbox => checkbox.checked)
      .map(checkbox => checkbox.value)
    
    if (selectedCategories.length > 0) {
      filters.categories = selectedCategories
    } else {
      delete filters.categories
    }
    
    // Sort
    if (this.hasSortSelectTarget && this.sortSelectTarget.value) {
      filters.sort = this.sortSelectTarget.value
    }
    
    return filters
  }

  // Perform search with current filters
  async search() {
    this.filters = this.gatherFilters()
    this.updateActiveFiltersDisplay()
    this.showLoading()
    
    const params = new URLSearchParams()
    
    // Build query parameters
    Object.entries(this.filters).forEach(([key, value]) => {
      if (Array.isArray(value)) {
        value.forEach(v => params.append(`filter_${key}[]`, v))
      } else {
        params.append(`filter_${key}`, value)
      }
    })
    
    const url = `${this.urlValue}?${params.toString()}`
    
    try {
      const response = await fetch(url, {
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (!response.ok) throw new Error('Filter request failed')
      
      const html = await response.text()
      this.renderResults(html)
      
      // Update URL without page reload
      window.history.pushState({}, '', url)
      
      // Track analytics
      this.trackFilterUsage()
      
    } catch (error) {
      console.error('Filter error:', error)
      this.showError()
    } finally {
      this.hideLoading()
    }
  }

  // Render search results
  renderResults(html) {
    if (!this.hasResultsTarget) return
    
    // Parse the HTML response
    const parser = new DOMParser()
    const doc = parser.parseFromString(html, 'text/html')
    
    // Extract results
    const resultsContainer = doc.querySelector('[data-filter-results]')
    if (resultsContainer) {
      this.resultsTarget.innerHTML = resultsContainer.innerHTML
      
      // Update result count
      const count = doc.querySelector('[data-result-count]')?.textContent
      if (count && this.hasResultCountTarget) {
        this.resultCountTarget.textContent = count
        
        // Animate count change
        this.resultCountTarget.classList.add('scale-110')
        setTimeout(() => {
          this.resultCountTarget.classList.remove('scale-110')
        }, 200)
      }
      
      // Scroll to results on mobile
      if (window.innerWidth < 768) {
        this.resultsTarget.scrollIntoView({ behavior: 'smooth', block: 'start' })
      }
    }
  }

  // Update active filters display
  updateActiveFiltersDisplay() {
    if (!this.hasActiveFiltersTarget) return
    
    const activeFilters = []
    
    // Price range
    if (this.filters.price_min || this.filters.price_max) {
      const min = this.formatPrice(this.filters.price_min || 0)
      const max = this.formatPrice(this.filters.price_max || '∞')
      activeFilters.push({
        label: 'Price',
        value: `${min} - ${max}`,
        key: 'price'
      })
    }
    
    // Categories
    if (this.filters.categories) {
      const categories = Array.isArray(this.filters.categories) 
        ? this.filters.categories 
        : [this.filters.categories]
      
      categories.forEach(cat => {
        const checkbox = this.categoryCheckboxTargets.find(cb => cb.value === cat)
        if (checkbox) {
          activeFilters.push({
            label: 'Category',
            value: checkbox.dataset.label || cat,
            key: 'category',
            removeValue: cat
          })
        }
      })
    }
    
    // Rating
    if (this.filters.rating) {
      activeFilters.push({
        label: 'Rating',
        value: `${this.filters.rating}+ stars`,
        key: 'rating'
      })
    }
    
    // Render filter pills
    if (activeFilters.length > 0) {
      this.activeFiltersTarget.innerHTML = `
        <div class="flex flex-wrap items-center gap-2 mb-4">
          <span class="text-sm font-medium text-gray-700">Active Filters:</span>
          ${activeFilters.map(filter => this.renderFilterPill(filter)).join('')}
          <button class="text-sm text-spirit-primary hover:text-spirit-secondary font-medium underline"
                  data-action="click->advanced-filters#clearAll">
            Clear All
          </button>
        </div>
      `
    } else {
      this.activeFiltersTarget.innerHTML = ''
    }
    
    // Show/hide clear button
    if (this.hasClearButtonTarget) {
      this.clearButtonTarget.classList.toggle('hidden', activeFilters.length === 0)
    }
  }

  renderFilterPill(filter) {
    return `
      <span class="inline-flex items-center space-x-2 px-3 py-1 bg-spirit-light rounded-full 
                   text-sm font-medium text-spirit-dark">
        <span>${filter.value}</span>
        <button class="hover:text-spirit-primary transition-colors duration-200"
                data-action="click->advanced-filters#removeFilter"
                data-filter-key="${filter.key}"
                data-filter-value="${filter.removeValue || ''}">
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"/>
          </svg>
        </button>
      </span>
    `
  }

  // Remove specific filter
  removeFilter(event) {
    const key = event.currentTarget.dataset.filterKey
    const value = event.currentTarget.dataset.filterValue
    
    if (key === 'price') {
      if (this.hasPriceMinTarget) this.priceMinTarget.value = this.priceMinTarget.min
      if (this.hasPriceMaxTarget) this.priceMaxTarget.value = this.priceMaxTarget.max
      delete this.filters.price_min
      delete this.filters.price_max
    } else if (key === 'category' && value) {
      const checkbox = this.categoryCheckboxTargets.find(cb => cb.value === value)
      if (checkbox) checkbox.checked = false
      
      if (Array.isArray(this.filters.categories)) {
        this.filters.categories = this.filters.categories.filter(c => c !== value)
        if (this.filters.categories.length === 0) delete this.filters.categories
      } else {
        delete this.filters.categories
      }
    } else if (key === 'rating') {
      this.ratingButtonTargets.forEach(btn => btn.classList.remove('active'))
      delete this.filters.rating
    }
    
    this.search()
  }

  // Clear all filters
  clearAll() {
    // Reset form inputs
    if (this.hasFormTarget) {
      this.formTarget.reset()
    }
    
    // Reset price sliders
    if (this.hasPriceMinTarget) {
      this.priceMinTarget.value = this.priceMinTarget.min
    }
    if (this.hasPriceMaxTarget) {
      this.priceMaxTarget.value = this.priceMaxTarget.max
    }
    
    // Clear rating buttons
    this.ratingButtonTargets.forEach(btn => btn.classList.remove('active'))
    
    // Clear filters object
    this.filters = {}
    
    // Perform search
    this.search()
  }

  // Show loading state
  showLoading() {
    if (this.hasLoadingSpinnerTarget) {
      this.loadingSpinnerTarget.classList.remove('hidden')
    }
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.add('opacity-50', 'pointer-events-none')
    }
  }

  // Hide loading state
  hideLoading() {
    if (this.hasLoadingSpinnerTarget) {
      this.loadingSpinnerTarget.classList.add('hidden')
    }
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.remove('opacity-50', 'pointer-events-none')
    }
  }

  // Show error message
  showError() {
    if (this.hasResultsTarget) {
      this.resultsTarget.innerHTML = `
        <div class="flex flex-col items-center justify-center py-12 space-y-4">
          <svg class="w-16 h-16 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                  d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          <h3 class="text-xl font-bold text-gray-900">Failed to Load Results</h3>
          <p class="text-gray-600">Please try again</p>
          <button class="spirit-button" data-action="click->advanced-filters#search">Retry</button>
        </div>
      `
    }
  }

  // Utility: Format price
  formatPrice(value) {
    if (value === '∞' || value === null || value === undefined) return '∞'
    return new Intl.NumberFormat('en-US', {
      style: 'currency',
      currency: 'USD'
    }).format(value)
  }

  // Utility: Debounce function
  debounce(func, delay) {
    let timeoutId
    return function(...args) {
      clearTimeout(timeoutId)
      timeoutId = setTimeout(() => func.apply(this, args), delay)
    }
  }

  // Track filter usage for analytics
  trackFilterUsage() {
    if (window.gtag) {
      window.gtag('event', 'filter_products', {
        filters: JSON.stringify(this.filters),
        filter_count: Object.keys(this.filters).length
      })
    }
  }
}