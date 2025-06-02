import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="mobile-menu"
export default class extends Controller {
  static targets = ["menu", "openIcon", "closeIcon"]
  
  connect() {
    // Ensure we have access to the menu
    if (!this.hasMenuTarget) {
      console.warn("Mobile menu target not found - will try to find by ID")
    }
  }
  
  toggle(event) {
    // Prevent default behavior
    event.preventDefault()
    
    // Get the menu element (either from targets or by ID as fallback)
    const menu = this.hasMenuTarget ? this.menuTarget : document.getElementById('mobile-menu')
    if (!menu) {
      console.error("Mobile menu element not found")
      return
    }
    
    // Toggle the menu visibility
    const isHidden = menu.classList.contains('hidden')
    menu.classList.toggle('hidden')
    
    // Toggle the icons if they exist
    if (this.hasOpenIconTarget && this.hasCloseIconTarget) {
      this.openIconTarget.classList.toggle('hidden', !isHidden)
      this.closeIconTarget.classList.toggle('hidden', isHidden)
    }
    
    // Update ARIA attributes for accessibility
    const button = event.currentTarget
    button.setAttribute('aria-expanded', isHidden ? 'true' : 'false')
  }
}
