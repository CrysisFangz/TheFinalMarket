// app/javascript/controllers/mobile_wallet_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["applePayButton", "googlePayButton", "amount"]
  static values = {
    orderId: String,
    amount: Number,
    currency: { type: String, default: "USD" },
    applePayUrl: { type: String, default: "/api/mobile/apple-pay-payment" },
    googlePayUrl: { type: String, default: "/api/mobile/google-pay-payment" }
  }

  connect() {
    this.checkWalletSupport()
  }

  async checkWalletSupport() {
    // Check Apple Pay support
    if (window.ApplePaySession && ApplePaySession.canMakePayments()) {
      this.showApplePayButton()
    }

    // Check Google Pay support
    if (window.google && window.google.payments) {
      this.checkGooglePayAvailability()
    } else {
      this.loadGooglePayScript()
    }
  }

  showApplePayButton() {
    if (this.hasApplePayButtonTarget) {
      this.applePayButtonTarget.classList.remove('hidden')
    }
  }

  async loadGooglePayScript() {
    const script = document.createElement('script')
    script.src = 'https://pay.google.com/gp/p/js/pay.js'
    script.onload = () => this.checkGooglePayAvailability()
    document.head.appendChild(script)
  }

  async checkGooglePayAvailability() {
    try {
      const paymentsClient = new google.payments.api.PaymentsClient({
        environment: this.isProduction() ? 'PRODUCTION' : 'TEST'
      })

      const isReadyToPayRequest = {
        apiVersion: 2,
        apiVersionMinor: 0,
        allowedPaymentMethods: [{
          type: 'CARD',
          parameters: {
            allowedAuthMethods: ['PAN_ONLY', 'CRYPTOGRAM_3DS'],
            allowedCardNetworks: ['AMEX', 'DISCOVER', 'MASTERCARD', 'VISA']
          }
        }]
      }

      const response = await paymentsClient.isReadyToPay(isReadyToPayRequest)
      
      if (response.result) {
        this.showGooglePayButton()
      }
    } catch (error) {
      console.error('Google Pay availability check failed:', error)
    }
  }

  showGooglePayButton() {
    if (this.hasGooglePayButtonTarget) {
      this.googlePayButtonTarget.classList.remove('hidden')
    }
  }

  async startApplePay() {
    try {
      const paymentRequest = {
        countryCode: 'US',
        currencyCode: this.currencyValue,
        supportedNetworks: ['visa', 'masterCard', 'amex', 'discover'],
        merchantCapabilities: ['supports3DS'],
        total: {
          label: 'TheFinalMarket',
          amount: this.amountValue.toString()
        }
      }

      const session = new ApplePaySession(3, paymentRequest)

      session.onvalidatemerchant = async (event) => {
        const merchantSession = await this.validateApplePayMerchant(event.validationURL)
        session.completeMerchantValidation(merchantSession)
      }

      session.onpaymentauthorized = async (event) => {
        const result = await this.processApplePayPayment(event.payment.token)
        
        if (result.success) {
          session.completePayment(ApplePaySession.STATUS_SUCCESS)
          this.handlePaymentSuccess(result)
        } else {
          session.completePayment(ApplePaySession.STATUS_FAILURE)
          this.handlePaymentError(result.error)
        }
      }

      session.oncancel = () => {
        this.handlePaymentCancelled()
      }

      session.begin()
    } catch (error) {
      console.error('Apple Pay failed:', error)
      this.handlePaymentError(error.message)
    }
  }

  async validateApplePayMerchant(validationURL) {
    const response = await fetch('/api/mobile/apple-pay-merchant-validation', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken
      },
      body: JSON.stringify({
        validation_url: validationURL,
        order_id: this.orderIdValue
      })
    })

    return await response.json()
  }

  async processApplePayPayment(paymentToken) {
    const response = await fetch(this.applePayUrlValue, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken
      },
      body: JSON.stringify({
        order_id: this.orderIdValue,
        payment_token: paymentToken
      })
    })

    return await response.json()
  }

  async startGooglePay() {
    try {
      const paymentsClient = new google.payments.api.PaymentsClient({
        environment: this.isProduction() ? 'PRODUCTION' : 'TEST'
      })

      const paymentDataRequest = await this.getGooglePayConfig()

      const paymentData = await paymentsClient.loadPaymentData(paymentDataRequest)
      
      const result = await this.processGooglePayPayment(paymentData.paymentMethodData.tokenizationData.token)
      
      if (result.success) {
        this.handlePaymentSuccess(result)
      } else {
        this.handlePaymentError(result.error)
      }
    } catch (error) {
      console.error('Google Pay failed:', error)
      
      if (error.statusCode === 'CANCELED') {
        this.handlePaymentCancelled()
      } else {
        this.handlePaymentError(error.message)
      }
    }
  }

  async getGooglePayConfig() {
    const response = await fetch('/api/mobile/google-pay-config', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken
      },
      body: JSON.stringify({
        order_id: this.orderIdValue
      })
    })

    return await response.json()
  }

  async processGooglePayPayment(paymentToken) {
    const response = await fetch(this.googlePayUrlValue, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken
      },
      body: JSON.stringify({
        order_id: this.orderIdValue,
        payment_token: paymentToken
      })
    })

    return await response.json()
  }

  handlePaymentSuccess(result) {
    // Show success message
    this.showMessage('Payment successful!', 'success')

    // Trigger success event
    const event = new CustomEvent('wallet:payment-success', {
      detail: result,
      bubbles: true
    })
    this.element.dispatchEvent(event)

    // Redirect to order confirmation
    if (result.order && result.order.id) {
      setTimeout(() => {
        window.location.href = `/orders/${result.order.id}`
      }, 1500)
    }
  }

  handlePaymentError(error) {
    this.showMessage(`Payment failed: ${error}`, 'error')

    const event = new CustomEvent('wallet:payment-error', {
      detail: { error },
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  handlePaymentCancelled() {
    this.showMessage('Payment cancelled', 'info')

    const event = new CustomEvent('wallet:payment-cancelled', {
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  showMessage(message, type = 'info') {
    // Create toast notification
    const toast = document.createElement('div')
    toast.className = `toast toast-${type}`
    toast.textContent = message
    document.body.appendChild(toast)

    setTimeout(() => {
      toast.classList.add('show')
    }, 100)

    setTimeout(() => {
      toast.classList.remove('show')
      setTimeout(() => toast.remove(), 300)
    }, 3000)
  }

  isProduction() {
    return window.location.hostname !== 'localhost' && 
           !window.location.hostname.includes('127.0.0.1')
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}

