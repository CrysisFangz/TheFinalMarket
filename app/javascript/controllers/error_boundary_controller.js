import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["error", "fallback", "retry"]
  static values = {
    maxRetries: { type: Number, default: 3 },
    retryDelay: { type: Number, default: 1000 }
  }

  connect() {
    this.retryCount = 0
    this.setupErrorHandling()
    this.setupUnhandledRejectionHandling()
  }

  setupErrorHandling() {
    // Catch JavaScript errors in child components
    this.originalErrorHandler = window.onerror

    window.onerror = (message, source, lineno, colno, error) => {
      this.handleError({
        type: 'JavaScript Error',
        message,
        source,
        line: lineno,
        column: colno,
        error,
        severity: 'high'
      })

      // Call original handler if it exists
      if (this.originalErrorHandler) {
        return this.originalErrorHandler(message, source, lineno, colno, error)
      }
    }
  }

  setupUnhandledRejectionHandling() {
    // Catch unhandled promise rejections
    this.originalRejectionHandler = window.onunhandledrejection

    window.onunhandledrejection = (event) => {
      this.handleError({
        type: 'Unhandled Promise Rejection',
        message: event.reason?.message || 'Unhandled promise rejection',
        reason: event.reason,
        severity: 'medium'
      })

      if (this.originalRejectionHandler) {
        return this.originalRejectionHandler(event)
      }
    }
  }

  handleError(errorInfo) {
    console.error('Error Boundary caught an error:', errorInfo)

    // Track error metrics
    this.trackError(errorInfo)

    // Show error UI
    this.showError(errorInfo)

    // Attempt recovery for certain error types
    if (this.isRecoverableError(errorInfo)) {
      this.attemptRecovery(errorInfo)
    }

    // Report to error tracking service
    this.reportError(errorInfo)
  }

  showError(errorInfo) {
    if (this.hasErrorTarget) {
      const errorElement = this.errorTarget
      errorElement.classList.remove('hidden')

      // Customize error message based on error type
      const errorMessage = this.getErrorMessage(errorInfo)
      const errorTitle = this.getErrorTitle(errorInfo)

      errorElement.innerHTML = `
        <div class="error-boundary-content">
          <div class="error-icon">⚠️</div>
          <h3 class="error-title">${errorTitle}</h3>
          <p class="error-message">${errorMessage}</p>
          ${this.hasRetryTarget ? '<button class="btn-retry">Try Again</button>' : ''}
          <details class="error-details">
            <summary>Technical Details</summary>
            <pre class="error-stack">${this.formatErrorDetails(errorInfo)}</pre>
          </details>
        </div>
      `

      // Add retry functionality
      const retryButton = errorElement.querySelector('.btn-retry')
      if (retryButton) {
        retryButton.addEventListener('click', () => this.retry())
      }
    }
  }

  hideError() {
    if (this.hasErrorTarget) {
      this.errorTarget.classList.add('hidden')
    }
  }

  showFallback() {
    if (this.hasFallbackTarget) {
      this.fallbackTarget.classList.remove('hidden')
      this.element.classList.add('has-fallback')
    }
  }

  hideFallback() {
    if (this.hasFallbackTarget) {
      this.fallbackTarget.classList.add('hidden')
      this.element.classList.remove('has-fallback')
    }
  }

  retry() {
    if (this.retryCount >= this.maxRetriesValue) {
      this.showMaxRetriesMessage()
      return
    }

    this.retryCount++
    this.hideError()
    this.hideFallback()

    // Show retry indicator
    this.showRetryIndicator()

    // Retry after delay
    setTimeout(() => {
      this.hideRetryIndicator()
      this.attemptRecovery()
    }, this.retryDelayValue)
  }

  showRetryIndicator() {
    if (!this.retryIndicator) {
      this.retryIndicator = document.createElement('div')
      this.retryIndicator.className = 'retry-indicator'
      this.retryIndicator.innerHTML = `
        <div class="retry-spinner"></div>
        <span>Retrying... (Attempt ${this.retryCount + 1}/${this.maxRetriesValue})</span>
      `
      this.element.appendChild(this.retryIndicator)
    }
  }

  hideRetryIndicator() {
    if (this.retryIndicator) {
      this.retryIndicator.remove()
      this.retryIndicator = null
    }
  }

  showMaxRetriesMessage() {
    if (this.hasErrorTarget) {
      const errorElement = this.errorTarget
      errorElement.innerHTML = `
        <div class="error-boundary-content max-retries">
          <div class="error-icon">😞</div>
          <h3 class="error-title">Unable to Load</h3>
          <p class="error-message">We've tried several times but couldn't load this content. Please refresh the page or try again later.</p>
          <button class="btn-refresh" onclick="window.location.reload()">Refresh Page</button>
        </div>
      `
    }
  }

  isRecoverableError(errorInfo) {
    // Define which errors are recoverable
    const recoverableErrors = [
      'NetworkError',
      'TimeoutError',
      'AbortError',
      'TypeError'
    ]

    return recoverableErrors.some(type =>
      errorInfo.message?.includes(type) ||
      errorInfo.type?.includes(type)
    )
  }

  attemptRecovery(errorInfo) {
    // Implement recovery strategies based on error type
    switch (errorInfo.type) {
      case 'NetworkError':
        this.retryNetworkRequest()
        break
      case 'JavaScript Error':
        this.reloadComponent()
        break
      default:
        this.showFallback()
    }
  }

  retryNetworkRequest() {
    // Re-attempt the failed network request
    const failedRequests = this.getFailedRequests()
    failedRequests.forEach(request => {
      fetch(request.url, request.options)
        .then(response => {
          if (response.ok) {
            this.hideError()
            this.reloadComponent()
          }
        })
        .catch(() => {
          // Will be caught by error handler
        })
    })
  }

  reloadComponent() {
    // Force reload of the component content
    const url = this.element.dataset.reloadUrl
    if (url) {
      fetch(url)
        .then(response => response.text())
        .then(html => {
          this.element.innerHTML = html
          this.hideError()
        })
        .catch(error => {
          console.error('Failed to reload component:', error)
        })
    }
  }

  trackError(errorInfo) {
    // Send error metrics to analytics
    if (window.gtag) {
      window.gtag('event', 'exception', {
        description: errorInfo.message,
        fatal: errorInfo.severity === 'high'
      })
    }
  }

  reportError(errorInfo) {
    // Report to error tracking service (e.g., Sentry, LogRocket)
    const errorReport = {
      message: errorInfo.message,
      stack: errorInfo.error?.stack,
      component: this.element.className,
      url: window.location.href,
      timestamp: new Date().toISOString(),
      userAgent: navigator.userAgent,
      retryCount: this.retryCount
    }

    // Send to error reporting endpoint
    fetch('/api/errors', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(errorReport)
    }).catch(console.error)
  }

  getErrorMessage(errorInfo) {
    const messages = {
      'NetworkError': 'Unable to connect to our servers. Please check your internet connection.',
      'TimeoutError': 'The request took too long to complete. Please try again.',
      'JavaScript Error': 'Something went wrong while loading this content.',
      'Unhandled Promise Rejection': 'An unexpected error occurred.'
    }

    return messages[errorInfo.type] || errorInfo.message || 'An unexpected error occurred.'
  }

  getErrorTitle(errorInfo) {
    const titles = {
      'NetworkError': 'Connection Problem',
      'TimeoutError': 'Request Timeout',
      'JavaScript Error': 'Loading Error',
      'Unhandled Promise Rejection': 'Unexpected Error'
    }

    return titles[errorInfo.type] || 'Something went wrong'
  }

  formatErrorDetails(errorInfo) {
    return JSON.stringify({
      type: errorInfo.type,
      message: errorInfo.message,
      source: errorInfo.source,
      line: errorInfo.line,
      column: errorInfo.column,
      timestamp: new Date().toISOString()
    }, null, 2)
  }

  getFailedRequests() {
    // This would need to be implemented based on your specific needs
    // For now, return empty array
    return []
  }

  disconnect() {
    // Restore original error handlers
    if (this.originalErrorHandler) {
      window.onerror = this.originalErrorHandler
    }

    if (this.originalRejectionHandler) {
      window.onunhandledrejection = this.originalRejectionHandler
    }
  }
}</parameter>
</edit_file>