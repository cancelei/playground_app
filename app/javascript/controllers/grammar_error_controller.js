import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="grammar-error"
export default class extends Controller {
  static targets = ["error"]
  
  connect() {
    console.log("Grammar error controller connected")
    console.log(`Found ${this.errorTargets.length} error targets`)
    
    // Initialize tooltips for all error targets
    this.errorTargets.forEach(error => {
      this.initializeTooltip(error)
    })
    
    // Add click listener to document to close tooltips when clicking outside
    document.addEventListener('click', this.handleDocumentClick.bind(this))
  }
  
  disconnect() {
    // Clean up event listeners
    document.removeEventListener('click', this.handleDocumentClick.bind(this))
  }
  
  initializeTooltip(errorElement) {
    console.log("Initializing tooltip for error element", errorElement)
    
    // Add event listeners for both mouse and touch events
    errorElement.addEventListener('mouseenter', this.showTooltip.bind(this))
    errorElement.addEventListener('mouseleave', this.hideTooltip.bind(this))
    errorElement.addEventListener('click', this.toggleTooltip.bind(this))
    errorElement.addEventListener('touchstart', this.handleTouch.bind(this), { passive: false })
  }
  
  handleTouch(event) {
    // Prevent default behavior to avoid scrolling on mobile
    event.preventDefault()
    
    // Toggle the tooltip
    this.toggleTooltip(event)
  }
  
  showTooltip(event) {
    const errorElement = event.currentTarget
    const tooltipElement = errorElement.querySelector('.grammar-tooltip')
    
    if (tooltipElement) {
      // Hide all other tooltips first
      this.hideAllTooltips()
      
      // Show this tooltip
      tooltipElement.classList.remove('hidden')
      tooltipElement.classList.add('block')
      
      // Position the tooltip
      this.positionTooltip(errorElement, tooltipElement)
    }
  }
  
  hideTooltip(event) {
    // Only hide on mouseleave if we're not on mobile
    if (window.innerWidth >= 640) {
      const errorElement = event.currentTarget
      const tooltipElement = errorElement.querySelector('.grammar-tooltip')
      
      if (tooltipElement) {
        tooltipElement.classList.add('hidden')
        tooltipElement.classList.remove('block')
      }
    }
  }
  
  toggleTooltip(event) {
    const errorElement = event.currentTarget
    const tooltipElement = errorElement.querySelector('.grammar-tooltip')
    
    if (tooltipElement) {
      if (tooltipElement.classList.contains('hidden')) {
        // Show this tooltip
        this.hideAllTooltips()
        tooltipElement.classList.remove('hidden')
        tooltipElement.classList.add('block')
        this.positionTooltip(errorElement, tooltipElement)
      } else {
        // Hide this tooltip
        tooltipElement.classList.add('hidden')
        tooltipElement.classList.remove('block')
      }
    }
  }
  
  hideAllTooltips() {
    // Hide all tooltips
    document.querySelectorAll('.grammar-tooltip').forEach(tooltip => {
      tooltip.classList.add('hidden')
      tooltip.classList.remove('block')
    })
  }
  
  handleDocumentClick(event) {
    // Check if the click was outside any error element
    const clickedOnError = this.errorTargets.some(error => 
      error === event.target || error.contains(event.target)
    )
    
    if (!clickedOnError) {
      this.hideAllTooltips()
    }
  }
  
  positionTooltip(errorElement, tooltipElement) {
    // Get the position of the error element
    const errorRect = errorElement.getBoundingClientRect()
    
    // Check if we're on mobile (viewport width < 640px)
    const isMobile = window.innerWidth < 640
    
    if (isMobile) {
      // On mobile, position the tooltip at the bottom of the error
      tooltipElement.style.left = '0'
      tooltipElement.style.transform = 'none'
    } else {
      // On desktop, center the tooltip above the error
      tooltipElement.style.left = '50%'
      tooltipElement.style.transform = 'translateX(-50%)'
    }
    
    // Make sure the tooltip doesn't go off-screen
    setTimeout(() => {
      const tooltipRect = tooltipElement.getBoundingClientRect()
      
      // Check if tooltip is off-screen to the left
      if (tooltipRect.left < 0) {
        tooltipElement.style.left = '0'
        tooltipElement.style.transform = 'none'
      }
      
      // Check if tooltip is off-screen to the right
      if (tooltipRect.right > window.innerWidth) {
        tooltipElement.style.left = 'auto'
        tooltipElement.style.right = '0'
        tooltipElement.style.transform = 'none'
      }
    }, 0)
  }
}
