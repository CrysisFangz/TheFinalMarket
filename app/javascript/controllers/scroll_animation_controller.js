// Scroll Animation Controller
// Handles revealing elements as they scroll into view
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["element", "animated"]

  connect() {
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('visible')
            // Optionally unobserve after animation
            // this.observer.unobserve(entry.target)
          }
        })
      },
      {
        threshold: 0.1,
        rootMargin: '0px 0px -100px 0px'
      }
    )

    // Observe both element and animated targets
    this.elementTargets.forEach((element) => {
      this.observer.observe(element)
    })
    
    this.animatedTargets.forEach((element) => {
      this.observer.observe(element)
    })
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }
}