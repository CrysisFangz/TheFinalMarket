// Scroll Top Controller
// Handles scroll-to-top button visibility and smooth scrolling
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button"]

  connect() {
    this.checkScrollPosition = this.checkScrollPosition.bind(this)
    window.addEventListener("scroll", this.checkScrollPosition, { passive: true })
    this.checkScrollPosition()
  }

  disconnect() {
    window.removeEventListener("scroll", this.checkScrollPosition)
  }

  checkScrollPosition() {
    if (this.hasButtonTarget) {
      const scrolled = window.pageYOffset || document.documentElement.scrollTop
      
      if (scrolled > 300) {
        this.buttonTarget.classList.remove("hidden")
        
        // Add fade in animation
        requestAnimationFrame(() => {
          this.buttonTarget.style.opacity = "1"
          this.buttonTarget.style.transform = "scale(1)"
        })
      } else {
        // Fade out animation
        this.buttonTarget.style.opacity = "0"
        this.buttonTarget.style.transform = "scale(0.8)"
        
        setTimeout(() => {
          this.buttonTarget.classList.add("hidden")
        }, 200)
      }
    }
  }

  toTop(event) {
    event.preventDefault()
    
    // Smooth scroll to top
    window.scrollTo({
      top: 0,
      behavior: "smooth"
    })
    
    // Optional: Focus on first focusable element for accessibility
    setTimeout(() => {
      const firstFocusable = document.querySelector('a, button, input, select, textarea')
      if (firstFocusable) {
        firstFocusable.focus()
      }
    }, 300)
  }

  // Scroll to a specific element
  scrollTo(event) {
    event.preventDefault()
    const targetId = event.currentTarget.dataset.scrollTarget
    const targetElement = document.getElementById(targetId)
    
    if (targetElement) {
      targetElement.scrollIntoView({
        behavior: "smooth",
        block: "start"
      })
    }
  }
}