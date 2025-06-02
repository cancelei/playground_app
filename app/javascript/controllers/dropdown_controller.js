import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown"
export default class extends Controller {
  static targets = ["menu", "arrow"]
  
  connect() {
    // Add a class to make debugging easier
    this.element.classList.add('dropdown-controller-connected')
    
    // Close dropdown when clicking outside
    this.clickOutsideHandler = this.clickOutside.bind(this)
    document.addEventListener("click", this.clickOutsideHandler)
  }
  
  disconnect() {
    document.removeEventListener("click", this.clickOutsideHandler)
  }
  
  toggle(event) {
    event.stopPropagation()
    
    // Toggle menu visibility
    this.menuTarget.classList.toggle("hidden")
    
    // Rotate arrow if it exists
    if (this.hasArrowTarget) {
      this.arrowTarget.classList.toggle("rotate-180")
    }
  }
  
  clickOutside(event) {
    // Only handle click outside if menu is visible
    if (!this.element.contains(event.target) && !this.menuTarget.classList.contains("hidden")) {
      this.menuTarget.classList.add("hidden")
      
      // Reset arrow rotation
      if (this.hasArrowTarget) {
        this.arrowTarget.classList.remove("rotate-180")
      }
    }
  }
}
