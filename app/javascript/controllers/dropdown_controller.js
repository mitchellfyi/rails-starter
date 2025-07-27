// Dropdown controller for notification and menu dropdowns
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "menu"]
  
  connect() {
    this.isOpen = false
    // Close dropdown when clicking outside
    document.addEventListener('click', this.closeOnOutsideClick.bind(this))
    document.addEventListener('keydown', this.closeOnEscape.bind(this))
  }
  
  disconnect() {
    document.removeEventListener('click', this.closeOnOutsideClick.bind(this))
    document.removeEventListener('keydown', this.closeOnEscape.bind(this))
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
    this.menuTarget.classList.remove('hidden')
    this.triggerTarget.setAttribute('aria-expanded', 'true')
    
    // Animate in
    this.menuTarget.classList.add('transition', 'ease-out', 'duration-100')
    this.menuTarget.classList.add('transform', 'opacity-0', 'scale-95')
    
    // Force reflow
    this.menuTarget.offsetHeight
    
    this.menuTarget.classList.remove('opacity-0', 'scale-95')
    this.menuTarget.classList.add('opacity-100', 'scale-100')
  }
  
  close() {
    this.isOpen = false
    this.triggerTarget.setAttribute('aria-expanded', 'false')
    
    // Animate out
    this.menuTarget.classList.add('transition', 'ease-in', 'duration-75')
    this.menuTarget.classList.remove('opacity-100', 'scale-100')
    this.menuTarget.classList.add('opacity-0', 'scale-95')
    
    // Hide after animation
    setTimeout(() => {
      if (!this.isOpen) {
        this.menuTarget.classList.add('hidden')
        this.menuTarget.classList.remove('transition', 'ease-in', 'duration-75', 'transform', 'opacity-0', 'scale-95')
      }
    }, 75)
  }
  
  closeOnOutsideClick(event) {
    if (this.isOpen && !this.element.contains(event.target)) {
      this.close()
    }
  }
  
  closeOnEscape(event) {
    if (this.isOpen && event.key === 'Escape') {
      this.close()
    }
  }
}