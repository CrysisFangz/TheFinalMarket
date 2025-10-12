// app/javascript/controllers/checkout_controller.js
import { Controller } from "@hotwired/stimulus"

/**
 * Checkout Controller
 * Handles multi-step checkout process with validation and progress tracking
 * 
 * @extends Controller
 * @example
 *   <div data-controller="checkout" data-checkout-step-value="1">
 *     ...
 *   </div>
 */
export default class extends Controller {
  static targets = [
    "step",
    "progressBar",
    "progressStep",
    "nextButton",
    "prevButton",
    "submitButton",
    "shippingForm",
    "paymentForm",
    "reviewForm",
    "shippingAddress",
    "paymentMethod",
    "orderSummary"
  ]

  static values = {
    step: { type: Number, default: 1 },
    totalSteps: { type: Number, default: 3 }
  }

  /**
   * Initialize checkout flow
   */
  connect() {
    console.log("Checkout controller connected")
    this.updateStep()
    this.validateCurrentStep()
  }

  /**
   * Go to next step with validation
   */
  nextStep(event) {
    event?.preventDefault()
    
    if (!this.validateCurrentStep()) {
      this.showValidationError()
      return
    }

    if (this.stepValue < this.totalStepsValue) {
      this.stepValue++
      this.updateStep()
      this.scrollToTop()
    }
  }

  /**
   * Go to previous step
   */
  prevStep(event) {
    event?.preventDefault()
    
    if (this.stepValue > 1) {
      this.stepValue--
      this.updateStep()
      this.scrollToTop()
    }
  }

  /**
   * Jump to specific step (from progress bar)
   */
  goToStep(event) {
    const targetStep = parseInt(event.currentTarget.dataset.step)
    
    // Only allow going backwards or to completed steps
    if (targetStep < this.stepValue) {
      this.stepValue = targetStep
      this.updateStep()
      this.scrollToTop()
    }
  }

  /**
   * Update UI for current step
   */
  updateStep() {
    // Hide all steps
    this.stepTargets.forEach(step => {
      step.classList.add("hidden")
    })

    // Show current step
    const currentStep = this.stepTargets[this.stepValue - 1]
    if (currentStep) {
      currentStep.classList.remove("hidden")
      currentStep.classList.add("animate-fade-in")
    }

    // Update progress bar
    this.updateProgressBar()

    // Update button visibility
    this.updateButtons()

    // Update progress steps
    this.updateProgressSteps()
  }

  /**
   * Update progress bar width
   */
  updateProgressBar() {
    if (!this.hasProgressBarTarget) return

    const progress = (this.stepValue / this.totalStepsValue) * 100
    this.progressBarTarget.style.width = `${progress}%`
    this.progressBarTarget.style.transition = "width 0.3s ease"
  }

  /**
   * Update progress step indicators
   */
  updateProgressSteps() {
    if (!this.hasProgressStepTarget) return

    this.progressStepTargets.forEach((step, index) => {
      const stepNumber = index + 1
      const isCompleted = stepNumber < this.stepValue
      const isCurrent = stepNumber === this.stepValue
      
      if (isCompleted) {
        step.classList.add("step-completed")
        step.classList.remove("step-current", "step-pending")
      } else if (isCurrent) {
        step.classList.add("step-current")
        step.classList.remove("step-completed", "step-pending")
      } else {
        step.classList.add("step-pending")
        step.classList.remove("step-completed", "step-current")
      }
    })
  }

  /**
   * Update button states
   */
  updateButtons() {
    // Previous button
    if (this.hasPrevButtonTarget) {
      if (this.stepValue === 1) {
        this.prevButtonTarget.classList.add("hidden")
      } else {
        this.prevButtonTarget.classList.remove("hidden")
      }
    }

    // Next button
    if (this.hasNextButtonTarget) {
      if (this.stepValue === this.totalStepsValue) {
        this.nextButtonTarget.classList.add("hidden")
      } else {
        this.nextButtonTarget.classList.remove("hidden")
      }
    }

    // Submit button
    if (this.hasSubmitButtonTarget) {
      if (this.stepValue === this.totalStepsValue) {
        this.submitButtonTarget.classList.remove("hidden")
      } else {
        this.submitButtonTarget.classList.add("hidden")
      }
    }
  }

  /**
   * Validate current step
   */
  validateCurrentStep() {
    switch (this.stepValue) {
      case 1:
        return this.validateShipping()
      case 2:
        return this.validatePayment()
      case 3:
        return true // Review step, no validation needed
      default:
        return true
    }
  }

  /**
   * Validate shipping information
   */
  validateShipping() {
    if (!this.hasShippingFormTarget) return true

    const form = this.shippingFormTarget
    const requiredFields = form.querySelectorAll("[required]")
    
    let isValid = true
    requiredFields.forEach(field => {
      if (!field.value.trim()) {
        isValid = false
        this.highlightInvalidField(field)
      } else {
        this.clearInvalidField(field)
      }
    })

    return isValid
  }

  /**
   * Validate payment information
   */
  validatePayment() {
    if (!this.hasPaymentFormTarget) return true

    const form = this.paymentFormTarget
    const requiredFields = form.querySelectorAll("[required]")
    
    let isValid = true
    requiredFields.forEach(field => {
      if (!field.value.trim()) {
        isValid = false
        this.highlightInvalidField(field)
      } else {
        this.clearInvalidField(field)
      }
    })

    return isValid
  }

  /**
   * Highlight invalid field
   */
  highlightInvalidField(field) {
    field.classList.add("border-red-500", "shake-animation")
    setTimeout(() => {
      field.classList.remove("shake-animation")
    }, 500)
  }

  /**
   * Clear invalid field styling
   */
  clearInvalidField(field) {
    field.classList.remove("border-red-500")
  }

  /**
   * Show validation error message
   */
  showValidationError() {
    // Create toast notification
    const toast = document.createElement("div")
    toast.className = "fixed top-4 right-4 bg-red-500 text-white px-6 py-4 rounded-lg shadow-lg z-50 animate-slide-in"
    toast.innerHTML = `
      <div class="flex items-center">
        <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
        </svg>
        <span>Please fill in all required fields</span>
      </div>
    `
    document.body.appendChild(toast)

    setTimeout(() => {
      toast.classList.add("animate-fade-out")
      setTimeout(() => toast.remove(), 300)
    }, 3000)
  }

  /**
   * Scroll to top of checkout area
   */
  scrollToTop() {
    this.element.scrollIntoView({ behavior: "smooth", block: "start" })
  }

  /**
   * Save shipping address for review
   */
  saveShippingForReview() {
    if (!this.hasShippingAddressTarget) return

    const form = this.shippingFormTarget
    const formData = new FormData(form)
    const address = {
      fullName: formData.get("full_name"),
      addressLine1: formData.get("address_line1"),
      addressLine2: formData.get("address_line2"),
      city: formData.get("city"),
      state: formData.get("state"),
      zipCode: formData.get("zip_code"),
      phone: formData.get("phone")
    }

    this.shippingAddressTarget.textContent = `
      ${address.fullName}
      ${address.addressLine1}
      ${address.addressLine2 ? address.addressLine2 + '\n' : ''}
      ${address.city}, ${address.state} ${address.zipCode}
      Phone: ${address.phone}
    `.trim()
  }

  /**
   * Handle form submission
   */
  submitOrder(event) {
    if (!this.validateCurrentStep()) {
      event.preventDefault()
      this.showValidationError()
      return
    }

    // Show loading state
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.innerHTML = `
        <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white inline-block" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Processing...
      `
    }
  }
}