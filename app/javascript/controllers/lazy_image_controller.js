import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "placeholder"]
  static values = {
    src: String,
    srcset: String,
    webp: String,
    webpSrcset: String,
    blur: String
  }

  connect() {
    this.loadImage()
  }

  loadImage() {
    // Show blur placeholder first
    if (this.hasBlurValue && this.hasPlaceholderTarget) {
      this.placeholderTarget.src = this.blurValue
      this.placeholderTarget.style.filter = 'blur(10px)'
    }

    // Use Intersection Observer for lazy loading
    if ('IntersectionObserver' in window) {
      this.observer = new IntersectionObserver(
        (entries) => this.handleIntersection(entries),
        {
          rootMargin: '50px 0px',
          threshold: 0.01
        }
      )
      
      this.observer.observe(this.element)
    } else {
      // Fallback for browsers without Intersection Observer
      this.loadActualImage()
    }
  }

  handleIntersection(entries) {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        this.loadActualImage()
        this.observer.unobserve(this.element)
      }
    })
  }

  loadActualImage() {
    const img = new Image()
    
    // Set up picture element for WebP support
    if (this.hasWebpValue) {
      this.createPictureElement()
    } else {
      this.loadStandardImage(img)
    }
  }

  createPictureElement() {
    const picture = document.createElement('picture')
    
    // WebP source
    if (this.hasWebpValue) {
      const webpSource = document.createElement('source')
      webpSource.type = 'image/webp'
      webpSource.srcset = this.webpSrcsetValue || this.webpValue
      picture.appendChild(webpSource)
    }
    
    // Fallback image
    const img = document.createElement('img')
    img.src = this.srcValue
    if (this.hasSrcsetValue) {
      img.srcset = this.srcsetValue
    }
    img.alt = this.element.dataset.alt || ''
    img.className = this.imageTarget?.className || 'img-fluid'
    img.loading = 'lazy'
    
    img.onload = () => this.handleImageLoad(picture)
    img.onerror = () => this.handleImageError()
    
    picture.appendChild(img)
    
    if (this.hasImageTarget) {
      this.imageTarget.replaceWith(picture)
    } else {
      this.element.appendChild(picture)
    }
  }

  loadStandardImage(img) {
    img.src = this.srcValue
    if (this.hasSrcsetValue) {
      img.srcset = this.srcsetValue
    }
    img.alt = this.element.dataset.alt || ''
    img.className = this.imageTarget?.className || 'img-fluid'
    img.loading = 'lazy'
    
    img.onload = () => this.handleImageLoad(img)
    img.onerror = () => this.handleImageError()
    
    if (this.hasImageTarget) {
      this.imageTarget.replaceWith(img)
    } else {
      this.element.appendChild(img)
    }
  }

  handleImageLoad(element) {
    // Fade in effect
    element.style.opacity = '0'
    element.style.transition = 'opacity 0.3s ease-in-out'
    
    requestAnimationFrame(() => {
      element.style.opacity = '1'
    })
    
    // Remove placeholder
    if (this.hasPlaceholderTarget) {
      setTimeout(() => {
        this.placeholderTarget.style.opacity = '0'
        setTimeout(() => {
          this.placeholderTarget.remove()
        }, 300)
      }, 100)
    }
    
    // Mark as loaded
    this.element.classList.add('loaded')
    this.element.classList.remove('loading')
  }

  handleImageError() {
    console.error('Failed to load image:', this.srcValue)
    
    // Show error placeholder
    if (this.hasPlaceholderTarget) {
      this.placeholderTarget.src = '/images/placeholder-error.png'
      this.placeholderTarget.style.filter = 'none'
    }
    
    this.element.classList.add('error')
    this.element.classList.remove('loading')
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}

