import { Controller } from "@hotwired/stimulus"

// Manages the trial countdown timer
export default class extends Controller {
  static targets = ["timer", "progress"]
  static values = { 
    end: Number,
    current: Number
  }
  
  connect() {
    console.log("Trial countdown controller connected")
    console.log(`End time: ${this.endValue}, Current time: ${this.currentValue}`)
    this.startCountdown()
  }
  
  disconnect() {
    console.log("Trial countdown controller disconnected")
    if (this.countdownTimer) {
      clearInterval(this.countdownTimer)
    }
  }
  
  startCountdown() {
    // Calculate initial remaining time
    const endTime = this.endValue
    let currentTime = Math.floor(Date.now() / 1000)
    let remainingSeconds = Math.max(0, endTime - currentTime)
    
    console.log(`Initial remaining seconds: ${remainingSeconds}`)
    
    // Initial update
    this.updateDisplay(remainingSeconds)
    
    // Set up interval to update every second
    this.countdownTimer = setInterval(() => {
      currentTime = Math.floor(Date.now() / 1000)
      remainingSeconds = Math.max(0, endTime - currentTime)
      
      console.log(`Updating countdown: ${remainingSeconds} seconds remaining`)
      this.updateDisplay(remainingSeconds)
      
      // If time's up, reload the page to trigger the login redirect
      if (remainingSeconds <= 0) {
        console.log("Trial time expired, reloading page")
        clearInterval(this.countdownTimer)
        setTimeout(() => {
          window.location.reload()
        }, 1000)
      }
    }, 1000)
  }
  
  updateDisplay(seconds) {
    // Update the timer text
    if (this.hasTimerTarget) {
      this.timerTarget.textContent = seconds
      console.log(`Updated timer display to: ${seconds}`)
    } else {
      console.warn("Timer target not found")
    }
    
    // Update the progress bar
    if (this.hasProgressTarget) {
      const totalDuration = 120 // 2 minutes in seconds
      const percentageRemaining = (seconds / totalDuration) * 100
      this.progressTarget.style.width = `${percentageRemaining}%`
      console.log(`Updated progress bar to: ${percentageRemaining}%`)
    } else {
      console.warn("Progress target not found")
    }
  }
}
