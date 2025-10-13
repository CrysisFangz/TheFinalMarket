import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["image", "content"]
  static values = {
    rootMargin: { type: String, default: "50px" },
    threshold: { type: Number, default: 0.1 }
  }

  connect() {
    this.setupIntersectionObserver()
    this.preloadCriticalImages()
  }

  setupIntersectionObserver() {
    if ('IntersectionObserver' in window) {
      this.observer = new IntersectionObserver(
        (entries) => this.handleIntersection(entries),
        {
          rootMargin: this.rootMarginValue,
          threshold: this.thresholdValue
        }
      )

      // Observe all image and content targets
      [...this.imageTargets, ...this.contentTargets].forEach(target => {
        this.observer.observe(target)
      })
    } else {
      // Fallback for older browsers
      this.loadAllContent()
    }
  }

  handleIntersection(entries) {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        if (entry.target.dataset.lazyImage) {
          this.loadImage(entry.target)
        } else if (entry.target.dataset.lazyContent) {
          this.loadContent(entry.target)
        }

        // Stop observing once loaded
        this.observer.unobserve(entry.target)
      }
    })
  }

  loadImage(imageElement) {
    const src = imageElement.dataset.lazyImage
    const srcset = imageElement.dataset.lazySrcset
    const placeholder = imageElement.querySelector('.image-placeholder')

    // Create new image for preloading
    const newImage = new Image()

    newImage.onload = () => {
      imageElement.src = src
      if (srcset) imageElement.srcset = srcset
      imageElement.classList.remove('loading')
      imageElement.classList.add('loaded')

      // Remove placeholder
      if (placeholder) {
        placeholder.style.opacity = '0'
        setTimeout(() => placeholder.remove(), 300)
      }
    }

    newImage.onerror = () => {
      imageElement.classList.remove('loading')
      imageElement.classList.add('error')
      console.error('Failed to load image:', src)
    }

    // Start loading
    imageElement.classList.add('loading')
    newImage.src = src
    if (srcset) newImage.srcset = srcset
  }

  loadContent(contentElement) {
    const contentType = contentElement.dataset.lazyContent

    switch (contentType) {
      case 'comments':
        this.loadComments(contentElement)
        break
      case 'reviews':
        this.loadReviews(contentElement)
        break
      case 'related-products':
        this.loadRelatedProducts(contentElement)
        break
      default:
        this.loadGenericContent(contentElement)
    }
  }

  async loadComments(element) {
    const productId = element.dataset.productId
    try {
      const response = await fetch(`/products/${productId}/comments`)
      const html = await response.text()
      element.innerHTML = html
      element.classList.add('loaded')
    } catch (error) {
      console.error('Failed to load comments:', error)
      element.innerHTML = '<p class="error">Failed to load comments</p>'
    }
  }

  async loadReviews(element) {
    const productId = element.dataset.productId
    try {
      const response = await fetch(`/products/${productId}/reviews`)
      const html = await response.text()
      element.innerHTML = html
      element.classList.add('loaded')
    } catch (error) {
      console.error('Failed to load reviews:', error)
      element.innerHTML = '<p class="error">Failed to load reviews</p>'
    }
  }

  async loadRelatedProducts(element) {
    const productId = element.dataset.productId
    try {
      const response = await fetch(`/products/${productId}/related`)
      const html = await response.text()
      element.innerHTML = html
      element.classList.add('loaded')
    } catch (error) {
      console.error('Failed to load related products:', error)
      element.innerHTML = '<p class="error">Failed to load related products</p>'
    }
  }

  async loadGenericContent(element) {
    const url = element.dataset.lazyUrl
    if (!url) return

    try {
      const response = await fetch(url)
      const html = await response.text()
      element.innerHTML = html
      element.classList.add('loaded')
    } catch (error) {
      console.error('Failed to load content:', error)
      element.innerHTML = '<p class="error">Failed to load content</p>'
    }
  }

  preloadCriticalImages() {
    // Preload images that are likely to be viewed soon
    const criticalImages = document.querySelectorAll('[data-critical-image]')

    criticalImages.forEach(img => {
      const link = document.createElement('link')
      link.rel = 'preload'
      link.as = 'image'
      link.href = img.src || img.dataset.lazyImage
      document.head.appendChild(link)
    })
  }

  loadAllContent() {
    // Fallback for browsers without IntersectionObserver
    this.imageTargets.forEach(img => {
      if (img.dataset.lazyImage) {
        this.loadImage(img)
      }
    })

    this.contentTargets.forEach(content => {
      if (content.dataset.lazyContent) {
        this.loadContent(content)
      }
    })
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}</parameter>
</edit_file>