import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="notification-toast"
export default class extends Controller {
  static values = { id: String }
  static classes = ["entering", "entered", "exiting"]

  connect() {
    // Show the toast with animation
    this.show()
    
    // Auto-dismiss after 5 seconds
    this.autoDismissTimeout = setTimeout(() => {
      this.dismiss()
    }, 5000)
  }

  disconnect() {
    if (this.autoDismissTimeout) {
      clearTimeout(this.autoDismissTimeout)
    }
  }

  show() {
    // Start with entering state
    this.element.classList.add(this.enteringClass)
    
    // Force reflow to ensure entering class is applied
    this.element.offsetHeight
    
    // Remove entering and add entered
    requestAnimationFrame(() => {
      this.element.classList.remove(this.enteringClass)
      this.element.classList.add(this.enteredClass)
    })
  }

  dismiss() {
    // Clear auto-dismiss timeout
    if (this.autoDismissTimeout) {
      clearTimeout(this.autoDismissTimeout)
      this.autoDismissTimeout = null
    }
    
    // Start exit animation
    this.element.classList.remove(this.enteredClass)
    this.element.classList.add(this.exitingClass)
    
    // Remove element after animation completes
    setTimeout(() => {
      this.element.remove()
    }, 300) // Match CSS transition duration
  }

  // Action handlers
  handleClick(event) {
    event.preventDefault()
    this.dismiss()
  }

  handleMouseEnter() {
    // Pause auto-dismiss when hovering
    if (this.autoDismissTimeout) {
      clearTimeout(this.autoDismissTimeout)
      this.autoDismissTimeout = null
    }
  }

  handleMouseLeave() {
    // Resume auto-dismiss when not hovering
    if (!this.autoDismissTimeout) {
      this.autoDismissTimeout = setTimeout(() => {
        this.dismiss()
      }, 2000) // Shorter timeout after interaction
    }
  }
}