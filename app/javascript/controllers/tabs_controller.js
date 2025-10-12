// Tabs Controller
// Handles tabbed content navigation with smooth transitions
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "panel"]

  switch(event) {
    event.preventDefault()
    const tabName = event.currentTarget.dataset.tab
    
    // Update button states
    this.buttonTargets.forEach(button => {
      if (button.dataset.tab === tabName) {
        button.classList.add('active', 'border-purple-600', 'text-purple-600')
        button.classList.remove('border-transparent', 'text-gray-500')
      } else {
        button.classList.remove('active', 'border-purple-600', 'text-purple-600')
        button.classList.add('border-transparent', 'text-gray-500')
      }
    })
    
    // Update panel visibility with fade animation
    this.panelTargets.forEach(panel => {
      if (panel.dataset.tab === tabName) {
        // Fade in
        panel.classList.remove('hidden')
        setTimeout(() => {
          panel.style.opacity = '1'
          panel.style.transform = 'translateY(0)'
        }, 10)
      } else {
        // Fade out
        panel.style.opacity = '0'
        panel.style.transform = 'translateY(10px)'
        setTimeout(() => {
          panel.classList.add('hidden')
        }, 200)
      }
    })
  }

  connect() {
    // Set initial styles for panels
    this.panelTargets.forEach(panel => {
      panel.style.transition = 'opacity 200ms ease-in-out, transform 200ms ease-in-out'
      panel.style.opacity = panel.classList.contains('hidden') ? '0' : '1'
      panel.style.transform = 'translateY(0)'
    })
  }
}