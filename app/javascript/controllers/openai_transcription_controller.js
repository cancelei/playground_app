import { Controller } from "@hotwired/stimulus"

// FULLY SIMULATED OPENAI TRANSCRIPTION CONTROLLER
// This is a complete simulation - NO API CALLS are made
export default class extends Controller {
  static targets = [ 
    "status", 
    "liveTranscript", 
    "finalTranscript", 
    "eventLog", 
    "startButton", 
    "stopButton",
    "costMetric",
    "latencyMetric", 
    "wordsMetric"
  ]
  
  connect() {
    this.peerConnection = null;
    this.dataChannel = null;
    this.audioElement = document.getElementById("audio-element");
    this.logEvent("Transcription controller connected");
    
    // Initialize metrics
    this.totalWords = 0;
    this.startTime = null;
    this.costPerMinute = 0.0002; // Estimated cost per minute of audio processed
    this.audioTime = 0;
  }
  
  async start() {
    try {
      this.statusTarget.textContent = "Initializing...";
      this.startButtonTarget.disabled = true;
      this.stopButtonTarget.disabled = false;
      
      // Reset metrics
      this.startTime = Date.now();
      this.totalWords = 0;
      this.audioTime = 0;
      this.updateMetrics();
      
      // Get CSRF token
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content');
      
      // Get ephemeral token from our backend (mocked)
      const tokenResponse = await fetch("/realtime/session", {
        method: "POST",
        headers: { 
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({
          intent: "transcription"
        })
      });
      
      const data = await tokenResponse.json();
      this.logEvent("Received mock session response");
      
      // SIMULATION MODE
      this.logEvent("🔵 SIMULATION MODE ACTIVE - Transcription Demo");
      
      // Request microphone access to test browser permissions
      this.logEvent("Requesting microphone access...");
      
      try {
        const mediaStream = await navigator.mediaDevices.getUserMedia({ audio: true });
        this.logEvent("✅ Microphone access granted");
        
        // Just for demo, stop the tracks immediately
        mediaStream.getTracks().forEach(track => track.stop());
      } catch (micError) {
        this.logEvent(`❌ Microphone access denied: ${micError.message}`);
        this.logEvent("Demo will continue in simulation mode only");
      }
      
      this.statusTarget.textContent = "Connected - Listening (Simulation)";
      this.logEvent("Simulation started - transcribing audio");
      
      // Run simulation of transcription
      this.runTranscriptionSimulation();
    } catch (error) {
      this.statusTarget.textContent = "Error";
      this.logEvent(`Error: ${error.message}`);
      this.resetUI();
      console.error(error);
    }
  }
  
  // Simulation method for transcription demo
  runTranscriptionSimulation() {
    // Sample phrases to simulate transcription
    const phrases = [
      "Hello there, I'm testing the OpenAI Realtime API transcription feature.",
      "This simulation shows how speech can be transcribed in real-time.",
      "Voice Activity Detection automatically detects when someone stops speaking.",
      "The transcription can be used for many applications like meeting notes, accessibility features, and voice commands.", 
      "OpenAI's models can transcribe speech with high accuracy across multiple languages."
    ];
    
    // Process each phrase with interim results and then final result
    let phraseIndex = 0;
    let audioTimeTotal = 0;
    
    const processNextPhrase = () => {
      if (phraseIndex >= phrases.length) {
        this.logEvent("Transcription simulation completed");
        return;
      }
      
      const phrase = phrases[phraseIndex];
      const words = phrase.split(/\s+/);
      const totalDuration = words.length * 300; // ~300ms per word on average
      
      this.logEvent(`Simulating speech: "${phrase}"`); 
      
      // Show interim results (partial transcription)
      let wordIndex = 0;
      const interimInterval = setInterval(() => {
        if (wordIndex >= words.length) {
          clearInterval(interimInterval);
          return;
        }
        
        // Update live transcript with partial results
        const partialPhrase = words.slice(0, wordIndex + 1).join(" ");
        this.liveTranscriptTarget.textContent = partialPhrase + "..."; 
        wordIndex++;
      }, 300);
      
      // After the whole phrase, show as final result
      setTimeout(() => {
        // Clear interim results
        this.liveTranscriptTarget.textContent = "";
        
        // Add to final transcript
        const timestamp = new Date().toLocaleTimeString();
        const finalText = `[${timestamp}] ${phrase}\n\n`;
        this.finalTranscriptTarget.innerHTML += finalText;
        
        // Update metrics
        audioTimeTotal += totalDuration / 1000; // Convert to seconds
        this.audioTime = audioTimeTotal;
        this.totalWords += words.length;
        this.updateMetrics();
        
        // Process next phrase after a pause
        phraseIndex++;
        setTimeout(processNextPhrase, 2000);
      }, totalDuration);
    };
    
    // Start the simulation after a brief delay
    setTimeout(processNextPhrase, 1000);
  }
  
  handleTranscriptionEvent(event) {
    this.logEvent(`Received event: ${event.type}`);
    
    switch (event.type) {
      case "transcript":
        if (event.transcript) {
          const text = event.transcript.text || "";
          const isFinal = event.transcript.final || false;
          
          if (isFinal) {
            // Final transcript - add to the final transcript area with timestamps
            const timestamp = new Date().toLocaleTimeString();
            const finalText = `[${timestamp}] ${text}\n\n`;
            this.finalTranscriptTarget.innerHTML += finalText;
            
            // Clear the live transcript area
            this.liveTranscriptTarget.innerHTML = "";
            
            // Update word count for metrics
            this.totalWords += text.split(/\s+/).filter(Boolean).length;
            this.audioTime += (event.transcript.duration_ms || 0) / 1000;
            this.updateMetrics();
          } else {
            // Interim result - update the live transcript area
            this.liveTranscriptTarget.innerHTML = text;
          }
        }
        break;
        
      case "error":
        this.logEvent(`Error: ${JSON.stringify(event.error)}`);
        break;
        
      default:
        // Handle other event types as needed
        console.log("Other event:", event);
    }
  }
  
  updateMetrics() {
    // Update cost metrics based on audio time
    const minutesOfAudio = this.audioTime / 60;
    const estimatedCost = (minutesOfAudio * this.costPerMinute).toFixed(4);
    this.costMetricTarget.textContent = `$${estimatedCost}`;
    
    // Update latency metrics
    if (this.startTime) {
      const elapsedMs = Date.now() - this.startTime;
      this.latencyMetricTarget.textContent = `${elapsedMs}ms total`;
    }
    
    // Update word count
    this.wordsMetricTarget.textContent = `${this.totalWords} words`;
  }
  
  sendEvent(event) {
    if (this.dataChannel && this.dataChannel.readyState === "open") {
      this.dataChannel.send(JSON.stringify(event));
      this.logEvent(`Sent event: ${event.type}`);
    } else {
      console.warn("Data channel not ready for sending events");
    }
  }
  
  stop() {
    this.logEvent("Stopping transcription simulation");
    
    // Clear any pending timeouts to stop the simulation
    for (let i = 0; i < 1000; i++) {
      window.clearTimeout(i);
      window.clearInterval(i);
    }
    
    this.resetUI();
    this.logEvent("Transcription simulation stopped");
    
    // Final metrics update - preserving the current metrics
    this.updateMetrics();
  }
  
  resetUI() {
    this.startButtonTarget.disabled = false;
    this.stopButtonTarget.disabled = true;
    this.statusTarget.textContent = "Idle";
    this.liveTranscriptTarget.innerHTML = "";
    
    // We don't clear finalTranscript as it shows the history
    // this.finalTranscriptTarget.innerHTML = "";
  }
  
  logEvent(message) {
    const timestamp = new Date().toLocaleTimeString();
    const logEntry = document.createElement("div");
    logEntry.textContent = `[${timestamp}] ${message}`;
    this.eventLogTarget.appendChild(logEntry);
    this.eventLogTarget.scrollTop = this.eventLogTarget.scrollHeight;
  }
}
