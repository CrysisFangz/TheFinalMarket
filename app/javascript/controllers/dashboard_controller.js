// app/javascript/controllers/dashboard_controller.js
import { Controller } from "@hotwired/stimulus"

/**
 * Dashboard Controller
 * Handles user dashboard interactions, widget management, and real-time updates
 * 
 * @extends Controller
 * @example
 *   <div data-controller="dashboard">
 *     <div data-dashboard-target="widget">...</div>
 *   </div>
 */
export default class extends Controller {
  static targets = [
    "widget",
    "activityFeed",
    "notification",
    "quickAction",
    "statCard",
    "chartContainer"
  ]

  static values = {
    userId: Number,
    refreshInterval: { type: Number, default: 60000 } // 60 seconds
  }

  /**
   * Initialize dashboard
   */
  connect() {
    console.log("Dashboard controller connected")
    this.startAutoRefresh()
    this.animateStatCards()
  }

  /**
   * Cleanup when controller disconnects
   */
  disconnect() {
    this.stopAutoRefresh()
  }

  /**
   * Start auto-refresh timer
   */
  startAutoRefresh() {
    if (this.hasRefreshIntervalValue) {
      this.refreshTimer = setInterval(() => {
        this.refreshActivityFeed()
        this.refreshNotifications()
      }, this.refreshIntervalValue)
    }
  }

  /**
   * Stop auto-refresh timer
   */
  stopAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
    }
  }

  /**
   * Refresh activity feed
   */
  async refreshActivityFeed() {
    if (!this.hasActivityFeedTarget) return

    try {
      const response = await fetch(`/dashboard/activity_feed`, {
        headers: {
          "Accept": "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (response.ok) {
        const html = await response.text()
        this.activityFeedTarget.innerHTML = html
        this.animateNewActivities()
      }
    } catch (error) {
      console.error("Failed to refresh activity feed:", error)
    }
  }

  /**
   * Refresh notifications count
   */
  async refreshNotifications() {
    if (!this.hasNotificationTarget) return

    try {
      const response = await fetch(`/notifications/count`, {
        headers: {
          "Accept": "application/json",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (response.ok) {
        const data = await response.json()
        this.updateNotificationBadge(data.unread_count)
      }
    } catch (error) {
      console.error("Failed to refresh notifications:", error)
    }
  }

  /**
   * Update notification badge
   */
  updateNotificationBadge(count) {
    const badge = this.element.querySelector(".notification-badge")
    if (badge) {
      if (count > 0) {
        badge.textContent = count > 99 ? "99+" : count
        badge.classList.remove("hidden")
        badge.classList.add("animate-bounce-once")
        setTimeout(() => badge.classList.remove("animate-bounce-once"), 1000)
      } else {
        badge.classList.add("hidden")
      }
    }
  }

  /**
   * Animate stat cards on load
   */
  animateStatCards() {
    if (!this.hasStatCardTarget) return

    this.statCardTargets.forEach((card, index) => {
      setTimeout(() => {
        card.classList.add("animate-scale-in")
        this.animateStatValue(card)
      }, index * 100)
    })
  }

  /**
   * Animate stat value counter
   */
  animateStatValue(card) {
    const valueElement = card.querySelector("[data-stat-value]")
    if (!valueElement) return

    const target = parseInt(valueElement.dataset.statValue)
    if (isNaN(target)) return

    const duration = 1500 // 1.5 seconds
    const steps = 60
    const increment = target / steps
    const stepDuration = duration / steps

    let current = 0
    const timer = setInterval(() => {
      current += increment
      if (current >= target) {
        current = target
        clearInterval(timer)
      }
      valueElement.textContent = Math.floor(current)
    }, stepDuration)
  }

  /**
   * Animate new activities
   */
  animateNewActivities() {
    const activities = this.activityFeedTarget.querySelectorAll(".activity-item")
    activities.forEach((activity, index) => {
      if (index < 3) { // Only animate newest 3
        activity.classList.add("animate-slide-in-right")
      }
    })
  }

  /**
   * Handle quick action clicks
   */
  handleQuickAction(event) {
    event.preventDefault()
    const action = event.currentTarget.dataset.action
    const button = event.currentTarget

    // Add loading state
    button.disabled = true
    button.classList.add("loading")

    // Simulate action (in real app, make API call)
    setTimeout(() => {
      button.disabled = false
      button.classList.remove("loading")
      this.showToast(`${action} completed successfully!`, "success")
    }, 1000)
  }

  /**
   * Toggle widget expansion
   */
  toggleWidget(event) {
    const widget = event.currentTarget.closest("[data-dashboard-target='widget']")
    const content = widget.querySelector(".widget-content")
    const icon = event.currentTarget.querySelector("svg")

    if (content.classList.contains("hidden")) {
      content.classList.remove("hidden")
      icon.style.transform = "rotate(180deg)"
    } else {
      content.classList.add("hidden")
      icon.style.transform = "rotate(0deg)"
    }
  }

  /**
   * Show toast notification
   */
  showToast(message, type = "info") {
    const toast = document.createElement("div")
    const colors = {
      success: "bg-green-500",
      error: "bg-red-500",
      info: "bg-blue-500",
      warning: "bg-yellow-500"
    }

    toast.className = `fixed top-4 right-4 ${colors[type]} text-white px-6 py-4 rounded-lg shadow-lg z-50 animate-slide-in`
    toast.innerHTML = `
      <div class="flex items-center">
        <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
        </svg>
        <span>${message}</span>
      </div>
    `
    document.body.appendChild(toast)

    setTimeout(() => {
      toast.classList.add("animate-fade-out")
      setTimeout(() => toast.remove(), 300)
    }, 3000)
  }

  /**
   * Export dashboard data
   */
  async exportData(event) {
    event.preventDefault()
    const format = event.currentTarget.dataset.format || "csv"

    try {
      const response = await fetch(`/dashboard/export?format=${format}`, {
        method: "GET",
        headers: {
          "Accept": "application/octet-stream"
        }
      })

      if (response.ok) {
        const blob = await response.blob()
        const url = window.URL.createObjectURL(blob)
        const a = document.createElement("a")
        a.href = url
        a.download = `dashboard_data_${new Date().toISOString().split('T')[0]}.${format}`
        document.body.appendChild(a)
        a.click()
        document.body.removeChild(a)
        window.URL.revokeObjectURL(url)
        
        this.showToast("Data exported successfully!", "success")
      } else {
        throw new Error("Export failed")
      }
    } catch (error) {
      console.error("Failed to export data:", error)
      this.showToast("Failed to export data", "error")
    }
  }

  /**
   * Filter activity feed
   */
  filterActivity(event) {
    const filter = event.currentTarget.dataset.filter
    const activities = this.activityFeedTarget.querySelectorAll(".activity-item")

    activities.forEach(activity => {
      if (filter === "all" || activity.dataset.type === filter) {
        activity.classList.remove("hidden")
      } else {
        activity.classList.add("hidden")
      }
    })

    // Update active filter button
    const buttons = this.element.querySelectorAll("[data-filter]")
    buttons.forEach(btn => {
      if (btn.dataset.filter === filter) {
        btn.classList.add("active")
      } else {
        btn.classList.remove("active")
      }
    })
  }

  /**
   * Load more activities
   */
  async loadMore(event) {
    event.preventDefault()
    const button = event.currentTarget
    const page = parseInt(button.dataset.page || 1) + 1

    button.disabled = true
    button.textContent = "Loading..."

    try {
      const response = await fetch(`/dashboard/activities?page=${page}`, {
        headers: {
          "Accept": "text/html",
          "X-Requested-With": "XMLHttpRequest"
        }
      })

      if (response.ok) {
        const html = await response.text()
        this.activityFeedTarget.insertAdjacentHTML("beforeend", html)
        button.dataset.page = page
        button.disabled = false
        button.textContent = "Load More"
      } else {
        throw new Error("Failed to load more")
      }
    } catch (error) {
      console.error("Failed to load more activities:", error)
      button.disabled = false
      button.textContent = "Try Again"
      this.showToast("Failed to load more activities", "error")
    }
  }
}