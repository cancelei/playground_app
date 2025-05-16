import { Controller } from "@hotwired/stimulus"

// OPENAI REALTIME CONTROLLER
// Makes real API calls to OpenAI using ephemeral token from backend
export default class extends Controller {
  static targets = ["status", "eventLog", "startButton", "stopButton", "userTranscript", "aiResponse", "modelSelect", "voiceSelect"];

  // Arrays to track simulation resources
  simulationTimeouts = [];
  simulationIntervals = [];
  
  connect() {
    this.startButtonTarget.disabled = false;
    this.stopButtonTarget.disabled = true;
    this.audioElement = document.getElementById("audio-element");
    this.logEvent("Simulation controller connected");
  }

  // Called when the start button is clicked
  async start() {
    try {
      this.logEvent("Starting OpenAI Realtime session");
      
      // Update UI state
      this.startButtonTarget.disabled = true;
      this.stopButtonTarget.disabled = false;
      this.statusTarget.textContent = "Initializing session...";
      
      // Clear previous content
      this.userTranscriptTarget.innerHTML = "";
      this.aiResponseTarget.innerHTML = "";
      
      // Get selected model and voice
      const selectedModel = this.modelSelectTarget.value;
      const selectedVoice = this.voiceSelectTarget.value;
      this.logEvent(`Selected model: ${selectedModel}, voice: ${selectedVoice}`);
      
      // Get CSRF token for Rails
      const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
      
      // Request ephemeral token from our backend
      this.logEvent("Requesting ephemeral token from server...");
      
      const tokenResponse = await fetch(`/realtime/session`, {
        method: "POST",
        headers: { 
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({
          model: selectedModel,
          voice: selectedVoice
        })
      });
      
      const data = await tokenResponse.json();
      
      if (data.error) {
        let errorMessage = `API Error: ${data.error}`;
        if (data.message) {
          // Try to extract more detailed error information
          const messageDetails = typeof data.message === 'object' ? 
            JSON.stringify(data.message) : data.message;
          errorMessage += ` - ${messageDetails}`;
        }
        
        this.logEvent(`❌ ${errorMessage}`);
        
        // Provide specific guidance based on common errors
        if (data.status_code === 401 || data.error.includes('unauthorized')) {
          this.logEvent('The API key may be invalid or not have access to the Realtime API.');
          this.logEvent('Make sure your API key is valid and has been granted access to the Realtime API beta.');
        } else if (data.status_code === 403 || data.error.includes('permission')) { 
          this.logEvent('Your account may not have access to the Realtime API beta.');
          this.logEvent('You need to be approved for the OpenAI Realtime API beta program.');
        } else if (data.error.includes('model')) {
          this.logEvent('The selected model may not be available or supported.');
          this.logEvent('Try using gpt-4o-mini-realtime-preview-2024-12-17 or check that the model exists.');
        }
        
        throw new Error(errorMessage);
      }
      
      if (!data.client_secret || !data.client_secret.value) {
        this.logEvent('❌ Response missing required ephemeral token');
        this.logEvent('Response structure is not as expected from the OpenAI API');
        throw new Error('Missing ephemeral token in response');
      }
      
      this.logEvent("✅ Received ephemeral token successfully");
      
      // Request microphone access FIRST
      this.statusTarget.textContent = "Requesting microphone access...";
      const mediaStream = await navigator.mediaDevices.getUserMedia({ audio: true });
      this.logEvent("✅ Microphone access granted");

      // Set up WebRTC connection and add microphone BEFORE offer
      this.statusTarget.textContent = "Connecting...";
      await this.setupWebRTCConnection(data, mediaStream);

      // Update status
      this.statusTarget.textContent = "Connected - Listening";
      this.logEvent("Ready for conversation!");
      
    } catch (error) {
      this.statusTarget.textContent = "Error";
      this.logEvent(`Error: ${error.message}`);
      this.resetUI();
    }
  }
  
  // Called when the stop button is clicked
  stop() {
    this.logEvent("Stopping OpenAI Realtime session");
    
    // Clean up WebRTC resources
    if (this.mediaStream) {
      this.mediaStream.getTracks().forEach(track => track.stop());
      this.mediaStream = null;
      this.logEvent("Stopped microphone tracks");
    }
    
    // Close data channel if it exists
    if (this.dataChannel) {
      this.dataChannel.close();
      this.dataChannel = null;
      this.logEvent("Closed data channel");
    }
    
    // Close peer connection if it exists
    if (this.peerConnection) {
      this.peerConnection.close();
      this.peerConnection = null;
      this.logEvent("Closed WebRTC peer connection");
    }
    
    // Clear all timeouts and intervals (for any remaining simulation resources)
    this.simulationTimeouts.forEach(timeout => clearTimeout(timeout));
    this.simulationIntervals.forEach(interval => clearInterval(interval));
    this.simulationTimeouts = [];
    this.simulationIntervals = [];
    
    // Reset audio element
    if (this.audioElement) {
      this.audioElement.srcObject = null;
      this.audioElement.pause();
    }
    
    // Reset UI
    this.resetUI();
    this.logEvent("Session stopped");
  }
  
  // Reset UI state
  resetUI() {
    this.startButtonTarget.disabled = false;
    this.stopButtonTarget.disabled = true;
    this.statusTarget.textContent = "Idle";
  }
  
  // WEBRTC METHODS
  
  // Set up WebRTC connection following OpenAI's official documentation pattern
  // Set up WebRTC connection following OpenAI's official documentation pattern
async setupWebRTCConnection(sessionData, mediaStream) {
    let sdpResponse;
    this.logEvent("Setting up WebRTC connection");
    
    try {
      // Create RTCPeerConnection
      const configuration = {
        iceServers: [
          { urls: 'stun:stun.l.google.com:19302' },
          { urls: 'stun:stun1.l.google.com:19302' }
        ]
      };
      
      this.peerConnection = new RTCPeerConnection(configuration);

    // Add audio track BEFORE creating offer
    if (mediaStream) {
      const audioTrack = mediaStream.getAudioTracks()[0];
      if (audioTrack) {
        this.audioSender = this.peerConnection.addTrack(audioTrack, mediaStream);
        this.logEvent("Added microphone audio track to WebRTC connection");
        this.mediaStream = mediaStream;
      } else {
        this.logEvent("No audio track found in mediaStream");
      }
    } else {
      this.logEvent("No mediaStream provided, offer may fail");
    }

    // Robust event handler for all OpenAI server events
    this.handleOpenAIEvent = (event) => {
      switch (event.type) {
        case "transcription":
          this.handleTranscriptionEvent(event);
          break;
        case "message":
          this.handleMessageEvent(event);
          break;
        case "response.done":
          this.handleResponseDoneEvent(event);
          break;
        case "function_call":
          this.handleFunctionCallEvent(event);
          break;
        case "function_call_output":
          // Optionally handle function call output events
          break;
        case "invalid_request_error":
          this.handleErrorEvent(event);
          break;
        case "speech_start":
          this.logEvent("Speech started");
          break;
        case "speech_end":
          this.logEvent("Speech ended");
          break;
        default:
          // Log full payload for unknown event types for debugging
          this.logEvent(`Received event: ${event.type} - ${JSON.stringify(event)}`);
          break;
      }
    }

    // Handle response.done events from OpenAI (AI output, function calls, etc)
    this.handleResponseDoneEvent = (event) => {
      this.logEvent(`response.done event: ${JSON.stringify(event)}`);
      // Try to extract and display the AI's output, if present
      if (event.response && event.response.output) {
        event.response.output.forEach(item => {
          if ((item.type === "text" || item.type === "message") && item.text) {
            this.aiResponseTarget.innerHTML += item.text + "<br>";
          }
          // Optionally handle other item types (function_call, audio, etc) here
        });
      }
    }

    // Handle streaming transcription events
    this.handleTranscriptionEvent = (event) => {
      const { text, is_final } = event.content;
      if (is_final) {
        this.userTranscriptTarget.innerHTML += text + "<br>";
      } else {
        this.userTranscriptTarget.innerHTML = this.userTranscriptTarget.innerHTML.replace(/<span class=\"interim\">.*<\/span>/g, "");
        this.userTranscriptTarget.innerHTML += `<span class=\"interim text-gray-400\">${text}</span>`;
      }
    }

    // Handle message events from the model
    this.handleMessageEvent = (event) => {
      const msgContent = event.content;
      if (msgContent && msgContent.text) {
        this.aiResponseTarget.innerHTML += msgContent.text;
      }
    }

    // Handle function call events (function calling flow)
    this.handleFunctionCallEvent = (event) => {
      // Example: { type: "function_call", name: "generate_horoscope", arguments: "{\"sign\":\"Aquarius\"}", call_id: "call_..." }
      const { name, arguments: args, call_id } = event;
      this.logEvent(`Function call requested: ${name} with args ${args}`);
      // You should implement your custom function logic here
      // For demo, we'll echo a fake result
      const output = { horoscope: "You will soon meet a new friend." };
      this.sendFunctionCallOutput(call_id, output);
    }

    // Send function call output back to the model
    this.sendFunctionCallOutput = (call_id, output) => {
      const event = {
        type: "conversation.item.create",
        item: {
          type: "function_call_output",
          call_id,
          output: JSON.stringify(output)
        }
      };
      if (this.dataChannel && this.dataChannel.readyState === "open") {
        this.dataChannel.send(JSON.stringify(event));
        this.logEvent(`Sent function_call_output for call_id ${call_id}`);
        // Trigger a model response
        this.dataChannel.send(JSON.stringify({ type: "response.create" }));
      } else {
        this.logEvent("Data channel not open, cannot send function_call_output");
      }
    }

    // Handle error events from the server
    this.handleErrorEvent = (event) => {
      this.logEvent(`❌ OpenAI error: ${event.message} (code: ${event.code}, param: ${event.param || "-"})`);
      if (event.event_id) {
        this.logEvent(`Error was triggered by client event_id: ${event.event_id}`);
      }
    };

    // Set up event handlers
    this.peerConnection.onicecandidate = (event) => {
        if (event.candidate) {
          this.logEvent("ICE candidate found");
        }
      };
      
      this.peerConnection.onconnectionstatechange = () => {
        this.logEvent(`Connection state: ${this.peerConnection.connectionState}`);
        
        if (this.peerConnection.connectionState === 'disconnected' || 
            this.peerConnection.connectionState === 'failed') {
          this.logEvent("WebRTC connection lost");
          this.stop();
        }
      };
      
      this.peerConnection.ontrack = (event) => {
        if (event.track.kind === 'audio') {
          this.logEvent("Received audio track from OpenAI");
          
          // Connect the audio track to the audio element
          if (this.audioElement) {
            this.audioElement.srcObject = event.streams[0];
            this.audioElement.play().catch(error => {
              this.logEvent(`Audio playback error: ${error.message}`);
            });
          }
        }
      };
      
      // Create data channel for sending/receiving text
      this.dataChannel = this.peerConnection.createDataChannel('openai');
      
      this.dataChannel.onopen = () => {
        this.logEvent("Data channel opened");
      };
      
      this.dataChannel.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          this.handleOpenAIEvent(data);
        } catch (error) {
          this.logEvent(`Error parsing data: ${error.message}`);
        }
      };
      
      this.dataChannel.onerror = (error) => {
        this.logEvent(`Data channel error: ${error}`);
      };
      
      this.dataChannel.onclose = () => {
        this.logEvent("Data channel closed");
      };
      
      // Create SDP offer
      const offer = await this.peerConnection.createOffer();
      await this.peerConnection.setLocalDescription(offer);
      
      // Wait for ICE gathering to complete
      await this.waitForIceGatheringComplete(this.peerConnection);
      
      // Verify ephemeral token exists and extract it exactly as shown in docs
      if (!sessionData || !sessionData.client_secret || !sessionData.client_secret.value) {
        this.logEvent("Error: Invalid session data received from server");
        this.logEvent("Session data doesn't contain expected client_secret structure");
        throw new Error("Missing ephemeral token in session data");
      }
      
      // Get an ephemeral key from the session data as shown in documentation
      const EPHEMERAL_KEY = sessionData.client_secret.value;
      this.logEvent("Ephemeral token received and validated");
      
      // Use a direct approach with the ephemeral token for SDP exchange
      this.logEvent("Attempting direct WebRTC connection with ephemeral token...");
      
      try {
        // Log the local description details for debugging
        this.logEvent(`Local description type: ${this.peerConnection.localDescription.type}`);
        this.logEvent(`Local description SDP length: ${this.peerConnection.localDescription.sdp.length} bytes`);
        
        // Follow exactly the approach in OpenAI documentation
        this.logEvent("Making SDP exchange request to OpenAI...");
        
        // Use the exact model format from the documentation
        // The UI selection might not have the correct format that the API expects
        const selectedModel = "gpt-4o-mini-realtime-preview-2024-12-17-preview-2024-12-17";
        
        // Log model being used
        this.logEvent(`Using model: ${selectedModel}`);
        
        // Exactly match the documentation code pattern
        try {
          const baseUrl = "https://api.openai.com/v1/realtime";
          sdpResponse = await fetch(`${baseUrl}?model=${selectedModel}`, {
            method: "POST",
            body: this.peerConnection.localDescription.sdp,
            headers: {
              "Authorization": `Bearer ${EPHEMERAL_KEY}`,
              "Content-Type": "application/sdp",
              "OpenAI-Beta": "realtime=v1"
            }
          });
          
          if (sdpResponse.ok) {
            this.logEvent("✅ Successfully connected to OpenAI Realtime API");
            // sdpResponse is already set
          } else {
            const errorBody = await sdpResponse.text();
            const errorMessage = `Error ${sdpResponse.status}: ${sdpResponse.statusText}`;
            this.logEvent(`❌ Connection failed: ${errorMessage}`);
            this.logEvent(`Error details: ${errorBody}`);
            
            // Check specifically for common model issues
            if (errorBody.includes("model")) {
              this.logEvent("The issue appears to be with the model parameter - trying with exact model format from docs");
              this.logEvent("Recommended model format: gpt-4o-mini-realtime-preview-2024-12-17-preview-2024-12-17");
            }
            
            throw new Error(errorMessage);
          }
        } catch (connectionError) {
          this.logEvent(`❌ WebRTC connection error: ${connectionError.message}`);
          
          // Add specific debugging for common issues
          if (connectionError.message.includes("NetworkError")) {
            this.logEvent("This appears to be a CORS issue - the browser blocked the request");
            this.logEvent("Try running this in a browser with CORS disabled for testing");
          } else if (connectionError.message.includes("401")) {
            this.logEvent("This appears to be an authentication issue with your token");
          } else if (connectionError.message.includes("404")) {
            this.logEvent("This endpoint may have changed in the API - check the latest docs");
          }
          
          throw connectionError;
        }
        
      } catch (connectionError) {
        this.logEvent(`❌ WebRTC connection error: ${connectionError.message}`);
        this.logEvent("There may be CORS issues or your API key might not have Realtime API access");
        throw connectionError;
      }

      // Strictly guard against sdpResponse not being set
      if (!sdpResponse) {
        this.logEvent("❌ WebRTC setup error: sdpResponse is not defined after SDP exchange attempt");
        throw new Error("sdpResponse is not defined after SDP exchange attempt");
      }
      if (!sdpResponse.ok) {
        const errorText = await sdpResponse.text();
        this.logEvent(`WebRTC connection failed: ${sdpResponse.status} ${sdpResponse.statusText}`);
        this.logEvent(`Error details: ${errorText}`);
        throw new Error(`WebRTC connection failed: ${sdpResponse.status} ${sdpResponse.statusText}`);
      }

      // Exactly match the documentation for handling the response
      const answer = {
        type: "answer",
        sdp: await sdpResponse.text()
      };
      
      // Apply the remote description
      await this.peerConnection.setRemoteDescription(answer);
      
      this.logEvent("✅ WebRTC connection established successfully");
      return this.peerConnection;
    } catch (error) {
      this.logEvent(`❌ WebRTC setup error: ${error.message}`);
      throw error; // Re-throw for proper handling upstream
    }
  }
  
  async waitForIceGatheringComplete(peerConnection) {
    if (peerConnection.iceGatheringState === 'complete') {
      return;
    }
    
    return new Promise((resolve) => {
      const checkState = () => {
        if (peerConnection.iceGatheringState === 'complete') {
          resolve();
        } else {
          setTimeout(checkState, 1000);
        }
      };
      
      checkState();
    });
  }
  
  connectMicrophone(mediaStream) {
    if (!this.peerConnection) {
      this.logEvent("Error: Peer connection not established");
      return;
    }
    
    // Add audio track to the peer connection
    const audioTrack = mediaStream.getAudioTracks()[0];
    if (audioTrack) {
      this.audioSender = this.peerConnection.addTrack(audioTrack, mediaStream);
      this.logEvent("Added microphone audio track to WebRTC connection");
      
      // Keep a reference to the media stream for cleanup
    } else {
      console.warn("Data channel not ready for sending events");
    }
  }
  
  // Utility method for logging events to the UI
  logEvent(message) {
    const timestamp = new Date().toLocaleTimeString();
    const logEntry = document.createElement("div");
    logEntry.textContent = `[${timestamp}] ${message}`;
    this.eventLogTarget.appendChild(logEntry);
    this.eventLogTarget.scrollTop = this.eventLogTarget.scrollHeight;
  }
}
