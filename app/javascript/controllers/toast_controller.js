import { Controller } from "@hotwired/stimulus"

// Advanced Toast Notification System
// Provides beautiful, customizable toast notifications with actions
export default class extends Controller {
  static values = {
    message: String,
    type: { type: String, default: 'info' }, // info, success, warning, error
    duration: { type: Number, default: 3000 },
    position: { type: String, default: 'top-right' }, // top-left, top-right, bottom-left, bottom-right, top-center, bottom-center
    action: Object,
    closeable: { type: Boolean, default: true }
  }

  connect() {
    if (this.hasMessageValue) {
      this.show()
    }
  }

  // Show toast notification
  show() {
    const toast = this.createToast()
    this.container.appendChild(toast)
    
    // Animate in
    requestAnimationFrame(() => {
      toast.classList.add('show')
    })
    
    // Auto dismiss
    if (this.durationValue > 0) {
      this.timeoutId = setTimeout(() => {
        this.dismiss(toast)
      }, this.durationValue)
    }
    
    // Track for progress bar
    if (this.durationValue > 0) {
      this.startProgressBar(toast)
    }
  }

  // Create toast element
  createToast() {
    const toast = document.createElement('div')
    toast.className = `toast toast-${this.typeValue}`
    toast.innerHTML = this.getToastHTML()
    
    // Add event listeners
    if (this.closeableValue) {
      const closeButton = toast.querySelector('.toast-close')
      closeButton?.addEventListener('click', () => this.dismiss(toast))
    }
    
    if (this.hasActionValue) {
      const actionButton = toast.querySelector('.toast-action')
      actionButton?.addEventListener('click', () => {
        this.handleAction()
        this.dismiss(toast)
      })
    }
    
    // Pause on hover
    toast.addEventListener('mouseenter', () => this.pause(toast))
    toast.addEventListener('mouseleave', () => this.resume(toast))
    
    return toast
  }

  // Generate toast HTML
  getToastHTML() {
    const icon = this.getIcon()
    const progressBar = this.durationValue > 0 ? '<div class="toast-progress"></div>' : ''
    
    return `
      ${progressBar}
      <div class="toast-content">
        <div class="toast-icon">
          ${icon}
        </div>
        <div class="toast-message">
          ${this.messageValue}
        </div>
        ${this.hasActionValue ? `
          <button class="toast-action">
            ${this.actionValue.label || 'Action'}
          </button>
        ` : ''}
        ${this.closeableValue ? `
          <button class="toast-close">
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"/>
            </svg>
          </button>
        ` : ''}
      </div>
    `
  }

  // Get icon based on type
  getIcon() {
    const icons = {
      success: `
        <svg class="w-6 h-6 text-green-500" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
        </svg>
      `,
      error: `
        <svg class="w-6 h-6 text-red-500" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
        </svg>
      `,
      warning: `
        <svg class="w-6 h-6 text-yellow-500" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
        </svg>
      `,
      info: `
        <svg class="w-6 h-6 text-blue-500" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd"/>
        </svg>
      `
    }
    
    return icons[this.typeValue] || icons.info
  }

  // Start progress bar animation
  startProgressBar(toast) {
    const progressBar = toast.querySelector('.toast-progress')
    if (!progressBar) return
    
    progressBar.style.animation = `toast-progress ${this.durationValue}ms linear`
  }

  // Pause auto-dismiss
  pause(toast) {
    if (this.timeoutId) {
      clearTimeout(this.timeoutId)
      const progressBar = toast.querySelector('.toast-progress')
      if (progressBar) {
        progressBar.style.animationPlayState = 'paused'
      }
    }
  }

  // Resume auto-dismiss
  resume(toast) {
    if (this.durationValue > 0) {
      const progressBar = toast.querySelector('.toast-progress')
      if (progressBar) {
        const elapsed = parseFloat(getComputedStyle(progressBar).width) / toast.offsetWidth
        const remaining = this.durationValue * (1 - elapsed)
        
        this.timeoutId = setTimeout(() => {
          this.dismiss(toast)
        }, remaining)
        
        progressBar.style.animationPlayState = 'running'
      }
    }
  }

  // Dismiss toast
  dismiss(toast) {
    toast.classList.remove('show')
    toast.classList.add('hide')
    
    setTimeout(() => {
      toast.remove()
    }, 300)
    
    if (this.timeoutId) {
      clearTimeout(this.timeoutId)
    }
  }

  // Handle action button click
  handleAction() {
    if (!this.hasActionValue) return
    
    const { callback, url, method } = this.actionValue
    
    if (callback && typeof window[callback] === 'function') {
      window[callback]()
    } else if (url) {
      if (method === 'POST') {
        this.postToUrl(url)
      } else {
        window.location.href = url
      }
    }
  }

  // POST to URL
  async postToUrl(url) {
    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': this.getCSRFToken(),
          'Accept': 'application/json'
        }
      })
      
      if (!response.ok) throw new Error('Request failed')
      
    } catch (error) {
      console.error('Action error:', error)
    }
  }

  // Get toast container
  get container() {
    let container = document.getElementById(`toast-container-${this.positionValue}`)
    
    if (!container) {
      container = document.createElement('div')
      container.id = `toast-container-${this.positionValue}`
      container.className = `toast-container toast-${this.positionValue}`
      document.body.appendChild(container)
    }
    
    return container
  }

  // Utility
  getCSRFToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  // Static method for easy usage
  static show(message, options = {}) {
    const event = new CustomEvent('toast:show', {
      detail: { message, ...options }
    })
    document.dispatchEvent(event)
  }
}

// Global toast function
window.showToast = (message, options = {}) => {
  const container = document.createElement('div')
  container.dataset.controller = 'toast'
  container.dataset.toastMessageValue = message
  container.dataset.toastTypeValue = options.type || 'info'
  container.dataset.toastDurationValue = options.duration || 3000
  container.dataset.toastPositionValue = options.position || 'top-right'
  
  if (options.action) {
    container.dataset.toastActionValue = JSON.stringify(options.action)
  }
  
  if (options.closeable !== undefined) {
    container.dataset.toastCloseableValue = options.closeable
  }
  
  document.body.appendChild(container)
  
  // Clean up after dismissal
  setTimeout(() => {
    container.remove()
  }, (options.duration || 3000) + 1000)
}

// Listen for toast events
document.addEventListener('toast:show', (event) => {
  const { message, ...options } = event.detail
  window.showToast(message, options)
})