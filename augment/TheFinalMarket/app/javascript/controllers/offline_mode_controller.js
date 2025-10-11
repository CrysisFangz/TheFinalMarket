// app/javascript/controllers/offline_mode_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "syncButton", "offlineIndicator"]
  static values = {
    syncUrl: { type: String, default: "/api/mobile/sync" }
  }

  connect() {
    this.pendingActions = this.loadPendingActions()
    this.offlineData = this.loadOfflineData()
    
    this.setupOnlineOfflineListeners()
    this.checkOnlineStatus()
    
    // Auto-sync when coming online
    if (navigator.onLine) {
      this.syncPendingActions()
    }
  }

  disconnect() {
    window.removeEventListener('online', this.handleOnline)
    window.removeEventListener('offline', this.handleOffline)
  }

  setupOnlineOfflineListeners() {
    this.handleOnline = () => {
      this.showOnlineStatus()
      this.syncPendingActions()
    }

    this.handleOffline = () => {
      this.showOfflineStatus()
    }

    window.addEventListener('online', this.handleOnline)
    window.addEventListener('offline', this.handleOffline)
  }

  checkOnlineStatus() {
    if (navigator.onLine) {
      this.showOnlineStatus()
    } else {
      this.showOfflineStatus()
    }
  }

  showOnlineStatus() {
    if (this.hasOfflineIndicatorTarget) {
      this.offlineIndicatorTarget.classList.add('hidden')
    }

    this.showStatus('Online', 'success')

    const event = new CustomEvent('offline:online', { bubbles: true })
    this.element.dispatchEvent(event)
  }

  showOfflineStatus() {
    if (this.hasOfflineIndicatorTarget) {
      this.offlineIndicatorTarget.classList.remove('hidden')
    }

    this.showStatus('Offline - Changes will sync when online', 'warning')

    const event = new CustomEvent('offline:offline', { bubbles: true })
    this.element.dispatchEvent(event)
  }

  // Cache product data for offline viewing
  async cacheProduct(productId, productData) {
    const cache = await caches.open('products-v1')
    const response = new Response(JSON.stringify(productData))
    await cache.put(`/products/${productId}`, response)

    // Also save to IndexedDB for structured queries
    await this.saveToIndexedDB('products', productId, productData)
  }

  // Cache user's cart for offline access
  async cacheCart(cartData) {
    const cache = await caches.open('cart-v1')
    const response = new Response(JSON.stringify(cartData))
    await cache.put('/cart', response)

    await this.saveToIndexedDB('cart', 'current', cartData)
  }

  // Cache wishlist
  async cacheWishlist(wishlistData) {
    const cache = await caches.open('wishlist-v1')
    const response = new Response(JSON.stringify(wishlistData))
    await cache.put('/wishlist', response)

    await this.saveToIndexedDB('wishlist', 'current', wishlistData)
  }

  // Queue action for later sync
  queueAction(action) {
    this.pendingActions.push({
      id: this.generateId(),
      action: action.type,
      data: action.data,
      timestamp: Date.now()
    })

    this.savePendingActions()

    this.showStatus(`Action queued for sync (${this.pendingActions.length} pending)`, 'info')

    if (navigator.onLine) {
      this.syncPendingActions()
    }
  }

  // Sync all pending actions
  async syncPendingActions() {
    if (this.pendingActions.length === 0) return

    if (!navigator.onLine) {
      this.showStatus('Cannot sync while offline', 'warning')
      return
    }

    this.showStatus('Syncing...', 'info')

    const successfulActions = []
    const failedActions = []

    for (const action of this.pendingActions) {
      try {
        await this.syncAction(action)
        successfulActions.push(action)
      } catch (error) {
        console.error('Failed to sync action:', action, error)
        failedActions.push(action)
      }
    }

    // Remove successful actions
    this.pendingActions = failedActions
    this.savePendingActions()

    if (failedActions.length === 0) {
      this.showStatus('All changes synced', 'success')
    } else {
      this.showStatus(`${successfulActions.length} synced, ${failedActions.length} failed`, 'warning')
    }

    const event = new CustomEvent('offline:synced', {
      detail: {
        successful: successfulActions.length,
        failed: failedActions.length
      },
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  async syncAction(action) {
    const response = await fetch(this.syncUrlValue, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken
      },
      body: JSON.stringify(action)
    })

    if (!response.ok) {
      throw new Error(`Sync failed: ${response.statusText}`)
    }

    return await response.json()
  }

  // IndexedDB operations
  async saveToIndexedDB(storeName, key, data) {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open('TheFinalMarketDB', 1)

      request.onerror = () => reject(request.error)

      request.onsuccess = () => {
        const db = request.result
        const transaction = db.transaction([storeName], 'readwrite')
        const store = transaction.objectStore(storeName)
        
        const putRequest = store.put({ id: key, data: data, timestamp: Date.now() })
        
        putRequest.onsuccess = () => resolve()
        putRequest.onerror = () => reject(putRequest.error)
      }

      request.onupgradeneeded = (event) => {
        const db = event.target.result
        
        if (!db.objectStoreNames.contains('products')) {
          db.createObjectStore('products', { keyPath: 'id' })
        }
        if (!db.objectStoreNames.contains('cart')) {
          db.createObjectStore('cart', { keyPath: 'id' })
        }
        if (!db.objectStoreNames.contains('wishlist')) {
          db.createObjectStore('wishlist', { keyPath: 'id' })
        }
      }
    })
  }

  async getFromIndexedDB(storeName, key) {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open('TheFinalMarketDB', 1)

      request.onerror = () => reject(request.error)

      request.onsuccess = () => {
        const db = request.result
        const transaction = db.transaction([storeName], 'readonly')
        const store = transaction.objectStore(storeName)
        
        const getRequest = store.get(key)
        
        getRequest.onsuccess = () => {
          resolve(getRequest.result?.data)
        }
        getRequest.onerror = () => reject(getRequest.error)
      }
    })
  }

  // LocalStorage operations for pending actions
  loadPendingActions() {
    const stored = localStorage.getItem('pendingActions')
    return stored ? JSON.parse(stored) : []
  }

  savePendingActions() {
    localStorage.setItem('pendingActions', JSON.stringify(this.pendingActions))
  }

  loadOfflineData() {
    const stored = localStorage.getItem('offlineData')
    return stored ? JSON.parse(stored) : {}
  }

  saveOfflineData() {
    localStorage.setItem('offlineData', JSON.stringify(this.offlineData))
  }

  // Utility methods
  generateId() {
    return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
  }

  showStatus(message, type = 'info') {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      this.statusTarget.className = `offline-status ${type}`
    }

    // Update sync button
    if (this.hasSyncButtonTarget) {
      if (this.pendingActions.length > 0) {
        this.syncButtonTarget.textContent = `Sync (${this.pendingActions.length})`
        this.syncButtonTarget.disabled = !navigator.onLine
      } else {
        this.syncButtonTarget.textContent = 'Sync'
        this.syncButtonTarget.disabled = true
      }
    }
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}

