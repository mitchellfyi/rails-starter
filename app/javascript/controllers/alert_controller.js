// Alert controller for dismissible alerts
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  dismiss() {
    this.element.remove()
  }
  
  // Auto-dismiss after specified time
  connect() {
    const autoDismiss = this.element.dataset.autoDismiss
    if (autoDismiss) {
      setTimeout(() => {
        this.dismiss()
      }, parseInt(autoDismiss) * 1000)
    }
  }
}