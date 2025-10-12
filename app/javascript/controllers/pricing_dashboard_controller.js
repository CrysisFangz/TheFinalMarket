import { Controller } from "@hotwired/stimulus"
import { Chart } from "chart.js/auto"

export default class extends Controller {
  static targets = [
    "productCheckbox",
    "selectAll",
    "chart",
    "priceInput",
    "recommendation"
  ]

  connect() {
    console.log("Pricing Dashboard controller connected")
    this.initializeCharts()
    this.loadRealtimeData()
  }

  disconnect() {
    if (this.charts) {
      Object.values(this.charts).forEach(chart => chart.destroy())
    }
    if (this.realtimeInterval) {
      clearInterval(this.realtimeInterval)
    }
  }

  // Toggle all product checkboxes
  toggleAll(event) {
    const checked = event.target.checked
    this.productCheckboxTargets.forEach(checkbox => {
      checkbox.checked = checked
    })
    this.updateBulkActions()
  }

  // Update bulk action button state
  updateBulkActions() {
    const selectedCount = this.productCheckboxTargets.filter(cb => cb.checked).length
    const bulkButton = this.element.querySelector('[data-action*="bulkOptimize"]')
    
    if (bulkButton) {
      bulkButton.disabled = selectedCount === 0
      bulkButton.textContent = selectedCount > 0 
        ? `Optimize ${selectedCount} Product${selectedCount > 1 ? 's' : ''}`
        : 'Optimize Selected'
    }
  }

  // Bulk optimize selected products
  async bulkOptimize(event) {
    event.preventDefault()
    
    const selectedIds = this.productCheckboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.value)
    
    if (selectedIds.length === 0) {
      alert('Please select at least one product')
      return
    }

    if (!confirm(`Optimize pricing for ${selectedIds.length} product(s)?`)) {
      return
    }

    const form = event.target.closest('form')
    const formData = new FormData(form)
    
    selectedIds.forEach(id => {
      formData.append('product_ids[]', id)
    })

    try {
      const response = await fetch(form.action, {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      if (response.ok) {
        window.location.reload()
      } else {
        alert('Failed to optimize pricing')
      }
    } catch (error) {
      console.error('Error optimizing pricing:', error)
      alert('An error occurred')
    }
  }

  // Apply price recommendation
  async applyRecommendation(event) {
    event.preventDefault()
    
    const productId = event.target.dataset.productId
    const recommendedPrice = event.target.dataset.recommendedPrice
    
    if (!confirm(`Apply recommended price of $${(recommendedPrice / 100).toFixed(2)}?`)) {
      return
    }

    try {
      const response = await fetch(`/seller/pricing/${productId}/apply_recommendation`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Content-Type': 'application/json'
        }
      })

      if (response.ok) {
        this.showSuccessMessage('Price updated successfully')
        setTimeout(() => window.location.reload(), 1000)
      } else {
        this.showErrorMessage('Failed to update price')
      }
    } catch (error) {
      console.error('Error applying recommendation:', error)
      this.showErrorMessage('An error occurred')
    }
  }

  // Initialize charts
  initializeCharts() {
    this.charts = {}
    
    this.chartTargets.forEach(canvas => {
      const chartType = canvas.dataset.chartType
      const chartData = JSON.parse(canvas.dataset.chartData || '{}')
      
      this.charts[chartType] = this.createChart(canvas, chartType, chartData)
    })
  }

  // Create a chart
  createChart(canvas, type, data) {
    const ctx = canvas.getContext('2d')
    
    const config = {
      type: type,
      data: data,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: true,
            position: 'bottom'
          },
          tooltip: {
            mode: 'index',
            intersect: false
          }
        },
        scales: type !== 'pie' ? {
          y: {
            beginAtZero: true,
            ticks: {
              callback: function(value) {
                return '$' + value.toFixed(2)
              }
            }
          }
        } : {}
      }
    }

    return new Chart(ctx, config)
  }

  // Load real-time pricing data
  loadRealtimeData() {
    // Update every 30 seconds
    this.realtimeInterval = setInterval(() => {
      this.fetchPricingUpdates()
    }, 30000)
  }

  // Fetch pricing updates
  async fetchPricingUpdates() {
    try {
      const response = await fetch('/seller/pricing/updates.json')
      const data = await response.json()
      
      this.updateDashboardMetrics(data)
    } catch (error) {
      console.error('Error fetching pricing updates:', error)
    }
  }

  // Update dashboard metrics
  updateDashboardMetrics(data) {
    // Update optimization score
    const scoreElement = this.element.querySelector('[data-metric="optimization-score"]')
    if (scoreElement && data.optimization_score) {
      this.animateValue(scoreElement, parseInt(scoreElement.textContent), data.optimization_score, 1000)
    }

    // Update price changes count
    const changesElement = this.element.querySelector('[data-metric="price-changes"]')
    if (changesElement && data.price_changes) {
      this.animateValue(changesElement, parseInt(changesElement.textContent), data.price_changes, 1000)
    }

    // Update revenue impact
    const revenueElement = this.element.querySelector('[data-metric="revenue-impact"]')
    if (revenueElement && data.revenue_impact) {
      revenueElement.textContent = '$' + (data.revenue_impact / 100).toFixed(2)
    }
  }

  // Animate number changes
  animateValue(element, start, end, duration) {
    const range = end - start
    const increment = range / (duration / 16)
    let current = start
    
    const timer = setInterval(() => {
      current += increment
      if ((increment > 0 && current >= end) || (increment < 0 && current <= end)) {
        current = end
        clearInterval(timer)
      }
      element.textContent = Math.round(current)
    }, 16)
  }

  // Export pricing report
  async exportReport(event) {
    event.preventDefault()
    
    try {
      const response = await fetch('/seller/pricing/export.csv', {
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })

      if (response.ok) {
        const blob = await response.blob()
        const url = window.URL.createObjectURL(blob)
        const a = document.createElement('a')
        a.href = url
        a.download = `pricing-report-${new Date().toISOString().split('T')[0]}.csv`
        document.body.appendChild(a)
        a.click()
        window.URL.revokeObjectURL(url)
        document.body.removeChild(a)
      } else {
        this.showErrorMessage('Failed to export report')
      }
    } catch (error) {
      console.error('Error exporting report:', error)
      this.showErrorMessage('An error occurred')
    }
  }

  // Show success message
  showSuccessMessage(message) {
    this.showToast(message, 'success')
  }

  // Show error message
  showErrorMessage(message) {
    this.showToast(message, 'error')
  }

  // Show toast notification
  showToast(message, type) {
    const toast = document.createElement('div')
    toast.className = `fixed top-4 right-4 px-6 py-3 rounded-lg shadow-lg text-white ${
      type === 'success' ? 'bg-green-500' : 'bg-red-500'
    } z-50 animate-fade-in`
    toast.textContent = message
    
    document.body.appendChild(toast)
    
    setTimeout(() => {
      toast.classList.add('animate-fade-out')
      setTimeout(() => document.body.removeChild(toast), 300)
    }, 3000)
  }

  // Price input validation
  validatePriceInput(event) {
    const input = event.target
    const value = parseFloat(input.value)
    const min = parseFloat(input.dataset.minPrice || 0)
    const max = parseFloat(input.dataset.maxPrice || Infinity)
    
    if (value < min) {
      input.value = min
      this.showErrorMessage(`Price cannot be less than $${min.toFixed(2)}`)
    } else if (value > max) {
      input.value = max
      this.showErrorMessage(`Price cannot be more than $${max.toFixed(2)}`)
    }
  }

  // Show price recommendation details
  showRecommendationDetails(event) {
    const productId = event.target.dataset.productId
    
    fetch(`/seller/pricing/${productId}/recommendations.json`)
      .then(response => response.json())
      .then(data => {
        this.displayRecommendationModal(data)
      })
      .catch(error => {
        console.error('Error fetching recommendation:', error)
        this.showErrorMessage('Failed to load recommendation')
      })
  }

  // Display recommendation modal
  displayRecommendationModal(data) {
    const modal = document.createElement('div')
    modal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50'
    modal.innerHTML = `
      <div class="bg-white rounded-lg p-8 max-w-2xl w-full mx-4 max-h-screen overflow-y-auto">
        <div class="flex justify-between items-center mb-6">
          <h2 class="text-2xl font-bold text-gray-900">Price Recommendation</h2>
          <button class="text-gray-400 hover:text-gray-600" data-action="click->pricing-dashboard#closeModal">
            <i class="fas fa-times text-2xl"></i>
          </button>
        </div>
        
        <div class="space-y-6">
          <div class="grid grid-cols-2 gap-4">
            <div class="bg-gray-50 rounded-lg p-4">
              <p class="text-sm text-gray-600">Current Price</p>
              <p class="text-2xl font-bold text-gray-900">$${(data.current_price / 100).toFixed(2)}</p>
            </div>
            <div class="bg-purple-50 rounded-lg p-4">
              <p class="text-sm text-purple-600">Recommended Price</p>
              <p class="text-2xl font-bold text-purple-600">$${(data.recommended_price / 100).toFixed(2)}</p>
            </div>
          </div>
          
          <div>
            <h3 class="font-semibold text-gray-900 mb-2">Reasoning</h3>
            <p class="text-gray-700">${data.reasoning}</p>
          </div>
          
          <div>
            <h3 class="font-semibold text-gray-900 mb-2">Expected Impact</h3>
            <div class="grid grid-cols-2 gap-4">
              <div>
                <p class="text-sm text-gray-600">Volume Change</p>
                <p class="text-lg font-semibold">${data.expected_impact.volume_change_percentage}%</p>
              </div>
              <div>
                <p class="text-sm text-gray-600">Revenue Change</p>
                <p class="text-lg font-semibold">${data.expected_impact.revenue_change_percentage}%</p>
              </div>
            </div>
          </div>
          
          <div class="flex gap-3">
            <button class="btn btn-primary flex-1" data-action="click->pricing-dashboard#applyRecommendation" data-product-id="${data.product_id}" data-recommended-price="${data.recommended_price}">
              Apply Recommendation
            </button>
            <button class="btn btn-outline flex-1" data-action="click->pricing-dashboard#closeModal">
              Cancel
            </button>
          </div>
        </div>
      </div>
    `
    
    document.body.appendChild(modal)
    this.currentModal = modal
  }

  // Close modal
  closeModal() {
    if (this.currentModal) {
      document.body.removeChild(this.currentModal)
      this.currentModal = null
    }
  }
}

