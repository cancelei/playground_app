import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false

// Make sure Stimulus is available in the global scope
window.Stimulus = { application }

export { application }
