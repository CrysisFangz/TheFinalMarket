import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["touchArea", "swipeContainer"]
  static values = {
    swipeThreshold: { type: Number, default: 50 },
    tapDelay: { type: Number, default: 300 }
  }

  connect() {
    this.detectMobile()
    this.setupTouchEvents()
    this.setupGestures()
    this.optimizeForMobile()
  }

  detectMobile() {
    this.isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)
    this.isTouch = 'ontouchstart' in window || navigator.maxTouchPoints > 0
    
    // Add mobile class to body
    if (this.isMobile) {
      document.body.classList.add('mobile-device')
    }
    
    if (this.isTouch) {
      document.body.classList.add('touch-device')
    }
    
    // Detect orientation
    this.updateOrientation()
    window.addEventListener('orientationchange', () => this.updateOrientation())
  }

  updateOrientation() {
    const orientation = window.innerHeight > window.innerWidth ? 'portrait' : 'landscape'
    document.body.classList.remove('portrait', 'landscape')
    document.body.classList.add(orientation)
  }

  setupTouchEvents() {
    if (!this.isTouch) return
    
    // Prevent 300ms tap delay
    this.element.addEventListener('touchstart', (e) => {
      this.touchStartTime = Date.now()
      this.touchStartX = e.touches[0].clientX
      this.touchStartY = e.touches[0].clientY
    })
    
    this.element.addEventListener('touchend', (e) => {
      const touchDuration = Date.now() - this.touchStartTime
      const touchEndX = e.changedTouches[0].clientX
      const touchEndY = e.changedTouches[0].clientY
      
      const deltaX = Math.abs(touchEndX - this.touchStartX)
      const deltaY = Math.abs(touchEndY - this.touchStartY)
      
      // Fast tap (< 300ms) with minimal movement
      if (touchDuration < this.tapDelayValue && deltaX < 10 && deltaY < 10) {
        this.handleFastTap(e)
      }
    })
    
    // Prevent double-tap zoom on specific elements
    let lastTap = 0
    this.element.addEventListener('touchend', (e) => {
      const currentTime = Date.now()
      const tapLength = currentTime - lastTap
      
      if (tapLength < 500 && tapLength > 0) {
        e.preventDefault()
        this.handleDoubleTap(e)
      }
      
      lastTap = currentTime
    })
  }

  setupGestures() {
    if (!this.hasSwipeContainerTarget) return
    
    let startX, startY, distX, distY
    
    this.swipeContainerTarget.addEventListener('touchstart', (e) => {
      const touch = e.touches[0]
      startX = touch.clientX
      startY = touch.clientY
    })
    
    this.swipeContainerTarget.addEventListener('touchmove', (e) => {
      if (!startX || !startY) return
      
      const touch = e.touches[0]
      distX = touch.clientX - startX
      distY = touch.clientY - startY
      
      // Prevent default if horizontal swipe
      if (Math.abs(distX) > Math.abs(distY)) {
        e.preventDefault()
      }
    })
    
    this.swipeContainerTarget.addEventListener('touchend', (e) => {
      if (!startX || !startY) return
      
      // Determine swipe direction
      if (Math.abs(distX) > this.swipeThresholdValue) {
        if (distX > 0) {
          this.handleSwipeRight()
        } else {
          this.handleSwipeLeft()
        }
      }
      
      if (Math.abs(distY) > this.swipeThresholdValue) {
        if (distY > 0) {
          this.handleSwipeDown()
        } else {
          this.handleSwipeUp()
        }
      }
      
      // Reset
      startX = null
      startY = null
      distX = 0
      distY = 0
    })
  }

  optimizeForMobile() {
    if (!this.isMobile) return
    
    // Optimize viewport
    this.setViewport()
    
    // Optimize touch targets
    this.optimizeTouchTargets()
    
    // Enable pull-to-refresh
    this.enablePullToRefresh()
    
    // Optimize scrolling
    this.optimizeScrolling()
    
    // Reduce animations on low-end devices
    this.optimizeAnimations()
  }

  setViewport() {
    let viewport = document.querySelector('meta[name="viewport"]')
    
    if (!viewport) {
      viewport = document.createElement('meta')
      viewport.name = 'viewport'
      document.head.appendChild(viewport)
    }
    
    viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes'
  }

  optimizeTouchTargets() {
    // Ensure minimum 44x44px touch targets
    const minSize = 44
    
    this.touchAreaTargets.forEach(target => {
      const rect = target.getBoundingClientRect()
      
      if (rect.width < minSize || rect.height < minSize) {
        target.style.minWidth = `${minSize}px`
        target.style.minHeight = `${minSize}px`
        target.style.display = 'inline-flex'
        target.style.alignItems = 'center'
        target.style.justifyContent = 'center'
      }
    })
  }

  enablePullToRefresh() {
    let startY = 0
    let pulling = false
    
    document.addEventListener('touchstart', (e) => {
      if (window.scrollY === 0) {
        startY = e.touches[0].clientY
        pulling = true
      }
    })
    
    document.addEventListener('touchmove', (e) => {
      if (!pulling) return
      
      const currentY = e.touches[0].clientY
      const pullDistance = currentY - startY
      
      if (pullDistance > 100) {
        this.showPullToRefreshIndicator()
      }
    })
    
    document.addEventListener('touchend', (e) => {
      if (!pulling) return
      
      const currentY = e.changedTouches[0].clientY
      const pullDistance = currentY - startY
      
      if (pullDistance > 100) {
        this.refresh()
      }
      
      this.hidePullToRefreshIndicator()
      pulling = false
    })
  }

  optimizeScrolling() {
    // Use momentum scrolling on iOS
    document.body.style.webkitOverflowScrolling = 'touch'
    
    // Passive event listeners for better scroll performance
    document.addEventListener('touchstart', () => {}, { passive: true })
    document.addEventListener('touchmove', () => {}, { passive: true })
  }

  optimizeAnimations() {
    // Detect low-end devices
    const isLowEnd = navigator.hardwareConcurrency <= 2 || 
                     navigator.deviceMemory <= 2
    
    if (isLowEnd) {
      document.body.classList.add('reduce-motion')
      
      // Disable expensive animations
      const style = document.createElement('style')
      style.textContent = `
        .reduce-motion * {
          animation-duration: 0.01ms !important;
          animation-iteration-count: 1 !important;
          transition-duration: 0.01ms !important;
        }
      `
      document.head.appendChild(style)
    }
  }

  handleFastTap(e) {
    // Dispatch custom fast tap event
    this.element.dispatchEvent(new CustomEvent('fast-tap', {
      detail: { originalEvent: e },
      bubbles: true
    }))
  }

  handleDoubleTap(e) {
    // Dispatch custom double tap event
    this.element.dispatchEvent(new CustomEvent('double-tap', {
      detail: { originalEvent: e },
      bubbles: true
    }))
  }

  handleSwipeLeft() {
    this.element.dispatchEvent(new CustomEvent('swipe-left', { bubbles: true }))
  }

  handleSwipeRight() {
    this.element.dispatchEvent(new CustomEvent('swipe-right', { bubbles: true }))
  }

  handleSwipeUp() {
    this.element.dispatchEvent(new CustomEvent('swipe-up', { bubbles: true }))
  }

  handleSwipeDown() {
    this.element.dispatchEvent(new CustomEvent('swipe-down', { bubbles: true }))
  }

  showPullToRefreshIndicator() {
    let indicator = document.querySelector('.pull-to-refresh-indicator')
    
    if (!indicator) {
      indicator = document.createElement('div')
      indicator.className = 'pull-to-refresh-indicator'
      indicator.innerHTML = '<div class="spinner-border" role="status"></div>'
      document.body.prepend(indicator)
    }
    
    indicator.classList.add('visible')
  }

  hidePullToRefreshIndicator() {
    const indicator = document.querySelector('.pull-to-refresh-indicator')
    if (indicator) {
      indicator.classList.remove('visible')
    }
  }

  refresh() {
    window.location.reload()
  }

  // Haptic feedback (if supported)
  vibrate(pattern = [10]) {
    if ('vibrate' in navigator) {
      navigator.vibrate(pattern)
    }
  }
}

