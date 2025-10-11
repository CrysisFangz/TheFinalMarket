// app/javascript/controllers/camera_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["video", "canvas", "preview", "captureButton", "switchButton"]
  static values = {
    visualSearchUrl: { type: String, default: "/api/mobile/visual-search" },
    mode: { type: String, default: "photo" } // photo, video, ar
  }

  connect() {
    this.stream = null
    this.facingMode = 'environment' // Start with back camera
    this.arSession = null
  }

  disconnect() {
    this.stopCamera()
    this.stopAR()
  }

  async startCamera() {
    try {
      const constraints = {
        video: {
          facingMode: this.facingMode,
          width: { ideal: 1920 },
          height: { ideal: 1080 }
        }
      }

      this.stream = await navigator.mediaDevices.getUserMedia(constraints)
      this.videoTarget.srcObject = this.stream
      await this.videoTarget.play()

      // Enable capture button
      if (this.hasCaptureButtonTarget) {
        this.captureButtonTarget.disabled = false
      }
    } catch (error) {
      console.error('Camera access failed:', error)
      this.showError('Camera access is required')
    }
  }

  stopCamera() {
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop())
      this.stream = null
    }

    if (this.videoTarget.srcObject) {
      this.videoTarget.srcObject = null
    }
  }

  async switchCamera() {
    this.facingMode = this.facingMode === 'user' ? 'environment' : 'user'
    
    if (this.stream) {
      this.stopCamera()
      await this.startCamera()
    }
  }

  capturePhoto() {
    if (!this.stream) return

    // Set canvas dimensions to match video
    this.canvasTarget.width = this.videoTarget.videoWidth
    this.canvasTarget.height = this.videoTarget.videoHeight

    // Draw current video frame to canvas
    const context = this.canvasTarget.getContext('2d')
    context.drawImage(this.videoTarget, 0, 0)

    // Get image data
    const imageData = this.canvasTarget.toDataURL('image/jpeg', 0.9)

    // Show preview
    this.showPreview(imageData)

    // Trigger capture event
    const event = new CustomEvent('camera:captured', {
      detail: { imageData },
      bubbles: true
    })
    this.element.dispatchEvent(event)

    return imageData
  }

  async visualSearch() {
    const imageData = this.capturePhoto()
    
    if (!imageData) return

    try {
      // Show loading state
      this.showLoading()

      const response = await fetch(this.visualSearchUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({ image: imageData })
      })

      const data = await response.json()

      if (data.success) {
        this.showSearchResults(data)
      } else {
        this.showError(data.error || 'Search failed')
      }
    } catch (error) {
      console.error('Visual search failed:', error)
      this.showError('Failed to search for similar products')
    } finally {
      this.hideLoading()
    }
  }

  async startAR() {
    if (!('xr' in navigator)) {
      this.showError('AR is not supported on this device')
      return
    }

    try {
      // Check if AR is supported
      const isARSupported = await navigator.xr.isSessionSupported('immersive-ar')
      
      if (!isARSupported) {
        this.showError('AR mode is not available')
        return
      }

      // Request AR session
      this.arSession = await navigator.xr.requestSession('immersive-ar', {
        requiredFeatures: ['hit-test', 'dom-overlay'],
        domOverlay: { root: this.element }
      })

      // Set up AR rendering
      await this.setupARSession()

      // Trigger AR started event
      const event = new CustomEvent('camera:ar-started', {
        detail: { session: this.arSession },
        bubbles: true
      })
      this.element.dispatchEvent(event)
    } catch (error) {
      console.error('AR session failed:', error)
      this.showError('Failed to start AR mode')
    }
  }

  async setupARSession() {
    // This is a simplified AR setup
    // In production, you'd use a library like Three.js or A-Frame
    
    const canvas = this.canvasTarget
    const gl = canvas.getContext('webgl', { xrCompatible: true })

    // Set up WebGL rendering layer
    const layer = new XRWebGLLayer(this.arSession, gl)
    await this.arSession.updateRenderState({ baseLayer: layer })

    // Get reference space
    const referenceSpace = await this.arSession.requestReferenceSpace('local')

    // Start render loop
    this.arSession.requestAnimationFrame((time, frame) => {
      this.onARFrame(time, frame, referenceSpace)
    })
  }

  onARFrame(time, frame, referenceSpace) {
    if (!this.arSession) return

    // Get viewer pose
    const pose = frame.getViewerPose(referenceSpace)

    if (pose) {
      // Render AR content here
      // This would typically involve rendering 3D models
      
      // Trigger frame event for custom AR rendering
      const event = new CustomEvent('camera:ar-frame', {
        detail: { time, frame, pose },
        bubbles: true
      })
      this.element.dispatchEvent(event)
    }

    // Continue render loop
    this.arSession.requestAnimationFrame((time, frame) => {
      this.onARFrame(time, frame, referenceSpace)
    })
  }

  stopAR() {
    if (this.arSession) {
      this.arSession.end()
      this.arSession = null
    }
  }

  // AR Try-On specific methods
  async tryOnProduct(productId, productImageUrl) {
    if (!this.arSession) {
      await this.startAR()
    }

    // Load product 3D model or image
    const event = new CustomEvent('camera:tryon-started', {
      detail: { productId, productImageUrl },
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  showPreview(imageData) {
    if (this.hasPreviewTarget) {
      this.previewTarget.src = imageData
      this.previewTarget.classList.remove('hidden')
    }
  }

  showSearchResults(data) {
    const event = new CustomEvent('camera:search-results', {
      detail: data,
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  showLoading() {
    // Dispatch loading event
    const event = new CustomEvent('camera:loading', { bubbles: true })
    this.element.dispatchEvent(event)
  }

  hideLoading() {
    const event = new CustomEvent('camera:loaded', { bubbles: true })
    this.element.dispatchEvent(event)
  }

  showError(message) {
    const event = new CustomEvent('camera:error', {
      detail: { message },
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}

