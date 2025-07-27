// Modal controller for overlay dialogs
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  
  connect() {
    // Bind escape key handler
    this.boundKeyHandler = this.handleKeydown.bind(this)
    document.addEventListener('keydown', this.boundKeyHandler)
  }
  
  disconnect() {
    document.removeEventListener('keydown', this.boundKeyHandler)
  }
  
  open() {
    this.element.classList.remove('hidden')
    document.body.classList.add('overflow-hidden')
    
    // Focus trap
    this.element.focus()
  }
  
  close() {
    this.element.classList.add('hidden')
    document.body.classList.remove('overflow-hidden')
  }
  
  // Close modal when clicking backdrop
  backdropClick(event) {
    if (event.target === this.element) {
      this.close()
    }
  }
  
  // Prevent modal from closing when clicking inside dialog
  stopPropagation(event) {
    event.stopPropagation()
  }
  
  // Handle escape key
  handleKeydown(event) {
    if (event.key === 'Escape' && !this.element.classList.contains('hidden')) {
      this.close()
    }
  }
}

// Helper function to open modal from anywhere
window.openModal = function(modalId) {
  const modal = document.getElementById(modalId)
  if (modal && modal.dataset.controller === 'modal') {
    const controller = application.getControllerForElementAndIdentifier(modal, 'modal')
    if (controller) {
      controller.open()
    }
  }
}

// Helper function to close modal from anywhere
window.closeModal = function(modalId) {
  const modal = document.getElementById(modalId)
  if (modal && modal.dataset.controller === 'modal') {
    const controller = application.getControllerForElementAndIdentifier(modal, 'modal')
    if (controller) {
      controller.close()
    }
  }
}