// Toast Controller - Enhanced
// Handles dismissible toast notifications with auto-hide
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    duration: { type: Number, default: 5000 }
  }

  connect() {
    // Auto-hide after duration
    this.hideTimeout = setTimeout(() => {
      this.close()
    }, this.durationValue)
  }

  close(event) {
    if (event) event.preventDefault()
    
    // Clear timeout if manually closed
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout)
    }
    
    // Animate out
    this.element.style.opacity = '0'
    this.element.style.transform = 'translateX(400px)'
    
    // Remove from DOM after animation
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }

  disconnect() {
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout)
    }
  }
}