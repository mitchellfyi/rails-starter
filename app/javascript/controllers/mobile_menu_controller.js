// Mobile menu controller for responsive navigation
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]
  static classes = ["open", "closed"]
  
  connect() {
    this.isOpen = false
  }
  
  toggle() {
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }
  
  open() {
    this.isOpen = true
    this.element.setAttribute('aria-expanded', 'true')
    if (this.hasMenuTarget) {
      this.menuTarget.classList.remove('hidden')
      this.menuTarget.classList.add('block')
    }
  }
  
  close() {
    this.isOpen = false
    this.element.setAttribute('aria-expanded', 'false')
    if (this.hasMenuTarget) {
      this.menuTarget.classList.remove('block')
      this.menuTarget.classList.add('hidden')
    }
  }
  
  // Close menu when clicking outside
  windowClick(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }
  
  // Handle escape key
  keydown(event) {
    if (event.key === 'Escape') {
      this.close()
    }
  }
}