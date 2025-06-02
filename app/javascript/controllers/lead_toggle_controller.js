import { Controller } from "@hotwired/stimulus"

// Manages the lead capture form toggle functionality
export default class extends Controller {
  static targets = ["form"]

  connect() {
    // Close the form when clicking outside
    document.addEventListener('click', this.handleOutsideClick.bind(this))
  }

  disconnect() {
    document.removeEventListener('click', this.handleOutsideClick.bind(this))
  }

  toggle(event) {
    event.stopPropagation()
    this.formTarget.classList.toggle('hidden')
  }

  handleOutsideClick(event) {
    // Only close if the form is open and the click is outside the component
    if (!this.formTarget.classList.contains('hidden') && 
        !this.element.contains(event.target)) {
      this.formTarget.classList.add('hidden')
    }
  }
}
