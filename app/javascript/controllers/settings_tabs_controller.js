// app/javascript/controllers/settings_tabs_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "panel"]

  connect() {
    // Store the currently active tab from URL hash or default to 'profile'
    const hash = window.location.hash.slice(1) || 'profile'
    this.showTab(hash)
  }

  switchTab(event) {
    event.preventDefault()
    const tabName = event.currentTarget.dataset.tab
    
    // Update URL hash without scrolling
    history.pushState(null, null, `#${tabName}`)
    
    this.showTab(tabName)
  }

  showTab(tabName) {
    // Remove active class from all buttons
    this.buttonTargets.forEach(button => {
      button.classList.remove('active')
    })

    // Hide all panels
    this.panelTargets.forEach(panel => {
      panel.classList.remove('active')
    })

    // Activate the selected tab
    const activeButton = this.buttonTargets.find(button => button.dataset.tab === tabName)
    const activePanel = this.panelTargets.find(panel => panel.dataset.panel === tabName)

    if (activeButton && activePanel) {
      activeButton.classList.add('active')
      activePanel.classList.add('active')
      
      // Smooth scroll to top of settings content
      activePanel.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
    }
  }

  // Handle browser back/forward buttons
  handlePopState() {
    const hash = window.location.hash.slice(1) || 'profile'
    this.showTab(hash)
  }
}

// Listen for popstate events (browser back/forward)
window.addEventListener('popstate', () => {
  const controller = document.querySelector('[data-controller~="settings-tabs"]')
  if (controller && controller.settingsTabsController) {
    controller.settingsTabsController.handlePopState()
  }
})