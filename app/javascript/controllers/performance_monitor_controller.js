import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["metrics"]

  connect() {
    this.setupPerformanceObserver()
    this.trackCoreWebVitals()
    this.monitorResourceLoading()
    this.setupErrorTracking()
  }

  setupPerformanceObserver() {
    if ('PerformanceObserver' in window) {
      // Monitor Largest Contentful Paint
      const lcpObserver = new PerformanceObserver((list) => {
        const entries = list.getEntries()
        const lastEntry = entries[entries.length - 1]
        this.recordMetric('LCP', lastEntry.startTime)
      })
      lcpObserver.observe({ entryTypes: ['largest-contentful-paint'] })

      // Monitor First Input Delay
      const fidObserver = new PerformanceObserver((list) => {
        const entries = list.getEntries()
        entries.forEach(entry => {
          this.recordMetric('FID', entry.processingStart - entry.startTime)
        })
      })
      fidObserver.observe({ entryTypes: ['first-input'] })

      // Monitor Cumulative Layout Shift
      const clsObserver = new PerformanceObserver((list) => {
        let clsValue = 0
        const entries = list.getEntries()
        entries.forEach(entry => {
          if (!entry.hadRecentInput) {
            clsValue += entry.value
          }
        })
        this.recordMetric('CLS', clsValue)
      })
      clsObserver.observe({ entryTypes: ['layout-shift'] })
    }
  }

  trackCoreWebVitals() {
    // Track Time to First Byte
    if (performance.timing) {
      const ttfb = performance.timing.responseStart - performance.timing.requestStart
      this.recordMetric('TTFB', ttfb)
    }

    // Track DOM Content Loaded
    window.addEventListener('DOMContentLoaded', () => {
      if (performance.timing) {
        const domContentLoaded = performance.timing.domContentLoadedEventEnd - performance.timing.navigationStart
        this.recordMetric('DCL', domContentLoaded)
      }
    })

    // Track Full Page Load
    window.addEventListener('load', () => {
      if (performance.timing) {
        const loadComplete = performance.timing.loadEventEnd - performance.timing.navigationStart
        this.recordMetric('Load Complete', loadComplete)
      }
    })
  }

  monitorResourceLoading() {
    if ('PerformanceObserver' in window) {
      const resourceObserver = new PerformanceObserver((list) => {
        const entries = list.getEntries()
        entries.forEach(entry => {
          if (entry.duration > 1000) { // Slow resources
            this.recordMetric('Slow Resource', {
              name: entry.name,
              duration: entry.duration,
              type: entry.initiatorType
            })
          }
        })
      })
      resourceObserver.observe({ entryTypes: ['resource'] })
    }
  }

  setupErrorTracking() {
    window.addEventListener('error', (event) => {
      this.recordError('JavaScript Error', {
        message: event.message,
        filename: event.filename,
        lineno: event.lineno,
        colno: event.colno
      })
    })

    window.addEventListener('unhandledrejection', (event) => {
      this.recordError('Unhandled Promise Rejection', {
        reason: event.reason
      })
    })
  }

  recordMetric(name, value) {
    const metric = {
      name,
      value,
      timestamp: Date.now(),
      url: window.location.href,
      userAgent: navigator.userAgent
    }

    // Send to analytics endpoint
    this.sendToAnalytics('/api/frontend-metrics', metric)

    // Display in development
    if (this.hasMetricsTarget) {
      this.displayMetric(metric)
    }

    console.log('Performance Metric:', metric)
  }

  recordError(type, error) {
    const errorData = {
      type,
      error,
      timestamp: Date.now(),
      url: window.location.href,
      userAgent: navigator.userAgent
    }

    // Send to error tracking endpoint
    this.sendToAnalytics('/api/frontend-errors', errorData)

    console.error('Frontend Error:', errorData)
  }

  sendToAnalytics(endpoint, data) {
    // Use sendBeacon for reliable delivery
    if ('sendBeacon' in navigator) {
      const blob = new Blob([JSON.stringify(data)], { type: 'application/json' })
      navigator.sendBeacon(endpoint, blob)
    } else {
      // Fallback to fetch
      fetch(endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(data),
        keepalive: true
      }).catch(console.error)
    }
  }

  displayMetric(metric) {
    const metricElement = document.createElement('div')
    metricElement.className = 'performance-metric'
    metricElement.innerHTML = `
      <small class="text-gray-600">
        ${metric.name}: ${typeof metric.value === 'object' ? JSON.stringify(metric.value) : metric.value + 'ms'}
      </small>
    `

    this.metricsTarget.appendChild(metricElement)
  }
}</parameter>
</edit_file>