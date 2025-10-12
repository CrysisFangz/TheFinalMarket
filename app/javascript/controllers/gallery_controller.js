// Gallery Controller
// Handles image gallery functionality with zoom and navigation
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["mainImage", "thumbnail"]

  connect() {
    this.currentIndex = 0
    this.images = this.thumbnailTargets.map(thumb => thumb.dataset.imageUrl || thumb.src)
  }

  select(event) {
    const index = parseInt(event.currentTarget.dataset.index)
    this.showImage(index)
    this.updateActiveThumbnail(index)
  }

  showImage(index) {
    if (index >= 0 && index < this.images.length) {
      this.currentIndex = index
      
      // Fade out
      this.mainImageTarget.style.opacity = '0'
      
      // Change image after fade
      setTimeout(() => {
        this.mainImageTarget.src = this.images[index]
        // Fade in
        this.mainImageTarget.style.opacity = '1'
      }, 200)
    }
  }

  updateActiveThumbnail(index) {
    this.thumbnailTargets.forEach((thumb, i) => {
      if (i === index) {
        thumb.classList.add('ring-4', 'ring-purple-500')
      } else {
        thumb.classList.remove('ring-4', 'ring-purple-500')
      }
    })
  }

  previous(event) {
    event.preventDefault()
    const newIndex = this.currentIndex > 0 ? this.currentIndex - 1 : this.images.length - 1
    this.showImage(newIndex)
    this.updateActiveThumbnail(newIndex)
  }

  next(event) {
    event.preventDefault()
    const newIndex = this.currentIndex < this.images.length - 1 ? this.currentIndex + 1 : 0
    this.showImage(newIndex)
    this.updateActiveThumbnail(newIndex)
  }

  zoom(event) {
    event.preventDefault()
    // Create fullscreen overlay
    const overlay = document.createElement('div')
    overlay.className = 'fixed inset-0 z-50 bg-black bg-opacity-90 flex items-center justify-center p-4'
    overlay.innerHTML = `
      <button class="absolute top-4 right-4 text-white hover:text-gray-300 transition-colors">
        <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
      <img src="${this.mainImageTarget.src}" class="max-w-full max-h-full object-contain" alt="Zoomed image">
    `
    
    document.body.appendChild(overlay)
    
    // Close on click
    overlay.addEventListener('click', () => {
      overlay.remove()
    })
    
    // Prevent body scrolling
    document.body.style.overflow = 'hidden'
    
    // Restore on removal
    overlay.addEventListener('transitionend', () => {
      if (!overlay.parentNode) {
        document.body.style.overflow = ''
      }
    })
  }
}