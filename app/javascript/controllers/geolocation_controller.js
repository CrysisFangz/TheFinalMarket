// app/javascript/controllers/geolocation_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "nearbyStores", "nearbyListings", "localDeals"]
  static values = {
    apiUrl: { type: String, default: "/api/mobile" },
    autoUpdate: { type: Boolean, default: false },
    updateInterval: { type: Number, default: 60000 } // 1 minute
  }

  connect() {
    this.currentPosition = null
    this.watchId = null
    
    if (this.autoUpdateValue) {
      this.startTracking()
    }
  }

  disconnect() {
    this.stopTracking()
  }

  async getCurrentLocation() {
    if (!('geolocation' in navigator)) {
      this.showError('Geolocation is not supported by your browser')
      return null
    }

    try {
      this.showStatus('Getting your location...', 'info')

      const position = await new Promise((resolve, reject) => {
        navigator.geolocation.getCurrentPosition(resolve, reject, {
          enableHighAccuracy: true,
          timeout: 10000,
          maximumAge: 0
        })
      })

      this.currentPosition = {
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
        accuracy: position.coords.accuracy
      }

      this.showStatus('Location found', 'success')
      
      // Trigger location update event
      const event = new CustomEvent('geolocation:updated', {
        detail: this.currentPosition,
        bubbles: true
      })
      this.element.dispatchEvent(event)

      return this.currentPosition
    } catch (error) {
      console.error('Geolocation error:', error)
      
      let message = 'Failed to get location'
      if (error.code === error.PERMISSION_DENIED) {
        message = 'Location permission denied'
      } else if (error.code === error.POSITION_UNAVAILABLE) {
        message = 'Location information unavailable'
      } else if (error.code === error.TIMEOUT) {
        message = 'Location request timed out'
      }
      
      this.showError(message)
      return null
    }
  }

  startTracking() {
    if (!('geolocation' in navigator)) return

    this.watchId = navigator.geolocation.watchPosition(
      (position) => {
        this.currentPosition = {
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
          accuracy: position.coords.accuracy
        }

        const event = new CustomEvent('geolocation:updated', {
          detail: this.currentPosition,
          bubbles: true
        })
        this.element.dispatchEvent(event)

        // Auto-refresh nearby content
        if (this.autoUpdateValue) {
          this.refreshNearbyContent()
        }
      },
      (error) => {
        console.error('Geolocation tracking error:', error)
      },
      {
        enableHighAccuracy: true,
        timeout: 10000,
        maximumAge: this.updateIntervalValue
      }
    )
  }

  stopTracking() {
    if (this.watchId) {
      navigator.geolocation.clearWatch(this.watchId)
      this.watchId = null
    }
  }

  async findNearbyStores(radius = 10) {
    const position = this.currentPosition || await this.getCurrentLocation()
    if (!position) return

    try {
      const response = await fetch(`${this.apiUrlValue}/nearby-stores`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({
          latitude: position.latitude,
          longitude: position.longitude,
          radius: radius
        })
      })

      const data = await response.json()

      if (this.hasNearbyStoresTarget) {
        this.renderStores(data.stores)
      }

      return data.stores
    } catch (error) {
      console.error('Failed to fetch nearby stores:', error)
      this.showError('Failed to load nearby stores')
    }
  }

  async findNearbyListings(radius = 25, category = null) {
    const position = this.currentPosition || await this.getCurrentLocation()
    if (!position) return

    try {
      const response = await fetch(`${this.apiUrlValue}/nearby-listings`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({
          latitude: position.latitude,
          longitude: position.longitude,
          radius: radius,
          category: category
        })
      })

      const data = await response.json()

      if (this.hasNearbyListingsTarget) {
        this.renderListings(data.listings)
      }

      return data.listings
    } catch (error) {
      console.error('Failed to fetch nearby listings:', error)
      this.showError('Failed to load nearby listings')
    }
  }

  async findLocalDeals(radius = 15) {
    const position = this.currentPosition || await this.getCurrentLocation()
    if (!position) return

    try {
      const response = await fetch(`${this.apiUrlValue}/local-deals`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({
          latitude: position.latitude,
          longitude: position.longitude,
          radius: radius
        })
      })

      const data = await response.json()

      if (this.hasLocalDealsTarget) {
        this.renderDeals(data.deals)
      }

      return data.deals
    } catch (error) {
      console.error('Failed to fetch local deals:', error)
      this.showError('Failed to load local deals')
    }
  }

  async checkGeofenceAlerts() {
    const position = this.currentPosition || await this.getCurrentLocation()
    if (!position) return

    try {
      const response = await fetch(`${this.apiUrlValue}/geofence-alerts`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({
          latitude: position.latitude,
          longitude: position.longitude
        })
      })

      const data = await response.json()

      if (data.alerts && data.alerts.length > 0) {
        this.showGeofenceAlerts(data.alerts)
      }

      return data.alerts
    } catch (error) {
      console.error('Failed to check geofence alerts:', error)
    }
  }

  async refreshNearbyContent() {
    await Promise.all([
      this.findNearbyStores(),
      this.findNearbyListings(),
      this.findLocalDeals(),
      this.checkGeofenceAlerts()
    ])
  }

  renderStores(stores) {
    const html = stores.map(store => `
      <div class="store-card" data-store-id="${store.id}">
        <img src="${store.image_url}" alt="${store.name}">
        <h3>${store.name}</h3>
        <p class="distance">${store.distance} km away</p>
        <p class="rating">⭐ ${store.rating}</p>
      </div>
    `).join('')

    this.nearbyStoresTarget.innerHTML = html
  }

  renderListings(listings) {
    const html = listings.map(listing => `
      <div class="listing-card" data-listing-id="${listing.id}">
        <img src="${listing.image_url}" alt="${listing.product_name}">
        <h3>${listing.product_name}</h3>
        <p class="price">$${listing.price}</p>
        <p class="distance">${listing.distance} km away</p>
        <p class="seller">${listing.seller_name}</p>
      </div>
    `).join('')

    this.nearbyListingsTarget.innerHTML = html
  }

  renderDeals(deals) {
    const html = deals.map(deal => `
      <div class="deal-card" data-deal-id="${deal.id}">
        <h3>${deal.title}</h3>
        <p>${deal.description}</p>
        <p class="discount">${deal.discount}% OFF</p>
        <p class="distance">${deal.distance} km away</p>
        <p class="expires">Expires: ${new Date(deal.expires_at).toLocaleDateString()}</p>
      </div>
    `).join('')

    this.localDealsTarget.innerHTML = html
  }

  showGeofenceAlerts(alerts) {
    alerts.forEach(alert => {
      // Show notification
      if ('Notification' in window && Notification.permission === 'granted') {
        new Notification(alert.title, {
          body: alert.message,
          icon: '/icon.png',
          badge: '/badge.png'
        })
      }

      // Trigger alert event
      const event = new CustomEvent('geolocation:alert', {
        detail: alert,
        bubbles: true
      })
      this.element.dispatchEvent(event)
    })
  }

  showStatus(message, type = 'info') {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      this.statusTarget.className = `geolocation-status ${type}`
    }
  }

  showError(message) {
    this.showStatus(message, 'error')
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}

