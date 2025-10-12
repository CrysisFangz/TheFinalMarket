// app/javascript/controllers/biometric_auth_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "enrollButton", "authenticateButton"]
  static values = {
    enrollUrl: { type: String, default: "/api/mobile/biometric/enroll" },
    authenticateUrl: { type: String, default: "/api/mobile/biometric/authenticate" },
    userId: String
  }

  connect() {
    this.checkBiometricSupport()
  }

  async checkBiometricSupport() {
    // Check if WebAuthn is supported
    if (!window.PublicKeyCredential) {
      this.showStatus('Biometric authentication is not supported on this device', 'error')
      this.disableButtons()
      return
    }

    // Check if platform authenticator is available
    const available = await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable()
    
    if (!available) {
      this.showStatus('No biometric authenticator found', 'error')
      this.disableButtons()
      return
    }

    // Check if user is already enrolled
    await this.checkEnrollmentStatus()
  }

  async checkEnrollmentStatus() {
    try {
      const response = await fetch(`${this.enrollUrlValue}/status`, {
        headers: {
          'X-CSRF-Token': this.csrfToken
        }
      })

      const data = await response.json()

      if (data.enrolled) {
        this.showStatus('Biometric authentication is enabled', 'success')
        if (this.hasEnrollButtonTarget) {
          this.enrollButtonTarget.textContent = 'Re-enroll'
        }
      } else {
        this.showStatus('Biometric authentication is available', 'info')
      }
    } catch (error) {
      console.error('Failed to check enrollment status:', error)
    }
  }

  async enroll() {
    try {
      this.showStatus('Setting up biometric authentication...', 'info')

      // Get challenge from server
      const challengeResponse = await fetch(`${this.enrollUrlValue}/challenge`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        }
      })

      const challengeData = await challengeResponse.json()

      // Create credential
      const credential = await navigator.credentials.create({
        publicKey: {
          challenge: this.base64ToArrayBuffer(challengeData.challenge),
          rp: {
            name: challengeData.rp_name,
            id: challengeData.rp_id
          },
          user: {
            id: this.base64ToArrayBuffer(challengeData.user_id),
            name: challengeData.user_name,
            displayName: challengeData.user_display_name
          },
          pubKeyCredParams: [
            { type: 'public-key', alg: -7 },  // ES256
            { type: 'public-key', alg: -257 } // RS256
          ],
          authenticatorSelection: {
            authenticatorAttachment: 'platform',
            userVerification: 'required',
            requireResidentKey: false
          },
          timeout: 60000,
          attestation: 'direct'
        }
      })

      // Send credential to server
      const enrollResponse = await fetch(this.enrollUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({
          credential: {
            id: credential.id,
            rawId: this.arrayBufferToBase64(credential.rawId),
            type: credential.type,
            response: {
              attestationObject: this.arrayBufferToBase64(credential.response.attestationObject),
              clientDataJSON: this.arrayBufferToBase64(credential.response.clientDataJSON)
            }
          }
        })
      })

      const enrollData = await enrollResponse.json()

      if (enrollData.success) {
        this.showStatus('Biometric authentication enabled successfully!', 'success')
        
        // Trigger enrollment success event
        const event = new CustomEvent('biometric:enrolled', {
          detail: enrollData,
          bubbles: true
        })
        this.element.dispatchEvent(event)
      } else {
        this.showStatus(enrollData.error || 'Enrollment failed', 'error')
      }
    } catch (error) {
      console.error('Biometric enrollment failed:', error)
      
      if (error.name === 'NotAllowedError') {
        this.showStatus('Biometric authentication was cancelled', 'error')
      } else {
        this.showStatus('Failed to enroll biometric authentication', 'error')
      }
    }
  }

  async authenticate() {
    try {
      this.showStatus('Authenticating...', 'info')

      // Get challenge from server
      const challengeResponse = await fetch(`${this.authenticateUrlValue}/challenge`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        }
      })

      const challengeData = await challengeResponse.json()

      // Get credential
      const assertion = await navigator.credentials.get({
        publicKey: {
          challenge: this.base64ToArrayBuffer(challengeData.challenge),
          rpId: challengeData.rp_id,
          allowCredentials: challengeData.credentials.map(cred => ({
            type: 'public-key',
            id: this.base64ToArrayBuffer(cred.id)
          })),
          userVerification: 'required',
          timeout: 60000
        }
      })

      // Send assertion to server
      const authResponse = await fetch(this.authenticateUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        },
        body: JSON.stringify({
          assertion: {
            id: assertion.id,
            rawId: this.arrayBufferToBase64(assertion.rawId),
            type: assertion.type,
            response: {
              authenticatorData: this.arrayBufferToBase64(assertion.response.authenticatorData),
              clientDataJSON: this.arrayBufferToBase64(assertion.response.clientDataJSON),
              signature: this.arrayBufferToBase64(assertion.response.signature),
              userHandle: assertion.response.userHandle ? 
                this.arrayBufferToBase64(assertion.response.userHandle) : null
            }
          }
        })
      })

      const authData = await authResponse.json()

      if (authData.success) {
        this.showStatus('Authentication successful!', 'success')
        
        // Trigger authentication success event
        const event = new CustomEvent('biometric:authenticated', {
          detail: authData,
          bubbles: true
        })
        this.element.dispatchEvent(event)

        // Redirect if URL provided
        if (authData.redirect_url) {
          window.location.href = authData.redirect_url
        }
      } else {
        this.showStatus(authData.error || 'Authentication failed', 'error')
      }
    } catch (error) {
      console.error('Biometric authentication failed:', error)
      
      if (error.name === 'NotAllowedError') {
        this.showStatus('Authentication was cancelled', 'error')
      } else {
        this.showStatus('Failed to authenticate', 'error')
      }
    }
  }

  // Quick authentication for payments
  async authenticateForPayment(amount) {
    try {
      const result = await this.authenticate()
      
      if (result) {
        const event = new CustomEvent('biometric:payment-authorized', {
          detail: { amount },
          bubbles: true
        })
        this.element.dispatchEvent(event)
      }
    } catch (error) {
      console.error('Payment authentication failed:', error)
    }
  }

  showStatus(message, type = 'info') {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
      this.statusTarget.className = `biometric-status ${type}`
    }

    // Also dispatch event
    const event = new CustomEvent('biometric:status', {
      detail: { message, type },
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  disableButtons() {
    if (this.hasEnrollButtonTarget) {
      this.enrollButtonTarget.disabled = true
    }
    if (this.hasAuthenticateButtonTarget) {
      this.authenticateButtonTarget.disabled = true
    }
  }

  // Utility methods for encoding/decoding
  base64ToArrayBuffer(base64) {
    const binaryString = atob(base64.replace(/-/g, '+').replace(/_/g, '/'))
    const bytes = new Uint8Array(binaryString.length)
    for (let i = 0; i < binaryString.length; i++) {
      bytes[i] = binaryString.charCodeAt(i)
    }
    return bytes.buffer
  }

  arrayBufferToBase64(buffer) {
    const bytes = new Uint8Array(buffer)
    let binary = ''
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i])
    }
    return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}

