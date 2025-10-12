// Quantity Controller
// Handles product quantity increment/decrement with validation
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  connect() {
    this.min = parseInt(this.inputTarget.min) || 1
    this.max = parseInt(this.inputTarget.max) || 999
  }

  increase(event) {
    event.preventDefault()
    const currentValue = parseInt(this.inputTarget.value) || this.min
    
    if (currentValue < this.max) {
      this.inputTarget.value = currentValue + 1
      this.animateButton(event.currentTarget)
    } else {
      this.showMaxMessage()
    }
  }

  decrease(event) {
    event.preventDefault()
    const currentValue = parseInt(this.inputTarget.value) || this.min
    
    if (currentValue > this.min) {
      this.inputTarget.value = currentValue - 1
      this.animateButton(event.currentTarget)
    }
  }

  animateButton(button) {
    button.classList.add('scale-95')
    setTimeout(() => {
      button.classList.remove('scale-95')
    }, 100)
  }

  showMaxMessage() {
    // Could trigger a toast notification
    console.log(`Maximum quantity is ${this.max}`)
  }

  validate(event) {
    let value = parseInt(event.target.value)
    
    if (isNaN(value) || value < this.min) {
      event.target.value = this.min
    } else if (value > this.max) {
      event.target.value = this.max
      this.showMaxMessage()
    }
  }
}