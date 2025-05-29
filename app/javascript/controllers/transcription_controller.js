import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="transcription"
export default class extends Controller {
  static targets = ["recordButton", "stopButton", "recordingStatus", "audioPreview", "audioPlayer", "transcriptionForm", "transcriptionText"]

  connect() {
    this.mediaRecorder = null
    this.audioChunks = []
    this.audioBlob = null
    this.audioUrl = null
  }

  startRecording() {
    // Request audio with specific constraints for better compatibility
    const constraints = {
      audio: {
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true
      }
    }
    
    navigator.mediaDevices.getUserMedia(constraints)
      .then(stream => {
        // Use WebM with Opus codec for better compatibility
        // If that's not supported, fall back to default
        const options = {
          mimeType: 'audio/webm;codecs=opus'
        }
        
        try {
          this.mediaRecorder = new MediaRecorder(stream, options)
          console.log('Using MIME type:', this.mediaRecorder.mimeType)
        } catch (e) {
          console.warn('WebM with Opus not supported, using default codec')
          this.mediaRecorder = new MediaRecorder(stream)
          console.log('Using MIME type:', this.mediaRecorder.mimeType)
        }
        
        this.audioChunks = []
        
        this.mediaRecorder.addEventListener('dataavailable', event => {
          if (event.data.size > 0) {
            this.audioChunks.push(event.data)
            console.log(`Received audio chunk: ${event.data.size} bytes`)
          }
        })
        
        this.mediaRecorder.addEventListener('stop', () => this.processRecording())
        
        // Request data every second to ensure we get data even if recording is interrupted
        this.mediaRecorder.start(1000)
        this.recordingStatusTarget.textContent = 'Recording...'
        this.recordButtonTarget.classList.add('hidden')
        this.stopButtonTarget.classList.remove('hidden')
      })
      .catch(err => {
        console.error('Error accessing microphone:', err)
        this.recordingStatusTarget.textContent = 'Error: Could not access microphone. Please ensure you have granted permission.'
      })
  }
  
  stopRecording() {
    if (this.mediaRecorder && this.mediaRecorder.state !== 'inactive') {
      this.mediaRecorder.stop()
      this.recordingStatusTarget.textContent = 'Processing audio...'
      this.stopButtonTarget.classList.add('hidden')
      this.recordButtonTarget.classList.remove('hidden')
      
      // Stop all audio tracks
      this.mediaRecorder.stream.getTracks().forEach(track => track.stop())
    }
  }
  
  processRecording() {
    // Determine the correct MIME type based on what was recorded
    const mimeType = this.mediaRecorder ? this.mediaRecorder.mimeType : 'audio/webm'
    console.log(`Creating blob with MIME type: ${mimeType}`)
    
    // Create a blob from the audio chunks with the correct MIME type
    this.audioBlob = new Blob(this.audioChunks, { type: mimeType })
    this.audioUrl = URL.createObjectURL(this.audioBlob)
    
    // Log blob size and type
    console.log(`Audio blob size: ${this.audioBlob.size} bytes`)
    console.log(`Audio blob type: ${this.audioBlob.type}`)
    
    if (this.audioBlob.size === 0) {
      console.error('Audio blob is empty!')
      this.recordingStatusTarget.textContent = 'Error: No audio data recorded. Please try again.'
      return
    }
    
    // Set the audio player source
    this.audioPlayerTarget.src = this.audioUrl
    this.audioPreviewTarget.classList.remove('hidden')
    
    // Add an event listener to check if the audio can be played
    this.audioPlayerTarget.addEventListener('canplay', () => {
      console.log('Audio can be played in the preview player')
    })
    
    this.audioPlayerTarget.addEventListener('error', (e) => {
      console.error('Error loading audio in preview player:', e)
    })
    
    // Convert blob to base64 for form submission
    const reader = new FileReader()
    reader.readAsDataURL(this.audioBlob)
    reader.onloadend = () => {
      const base64data = reader.result
      console.log(`Base64 data length: ${base64data.length} characters`)
      console.log(`Base64 data starts with: ${base64data.substring(0, 50)}...`)
      
      // Store the audio data in the form
      const audioDataInput = document.getElementById('transcription_audio_data')
      audioDataInput.value = base64data
      
      // Store the audio data as a data attribute on the form for later retrieval
      this.transcriptionFormTarget.dataset.audioData = base64data
      
      // Also store the MIME type for reference
      this.transcriptionFormTarget.dataset.audioMimeType = mimeType
      
      // Verify the data was set
      console.log(`Audio data input value length: ${audioDataInput.value.length} characters`)
      
      // Now transcribe the audio
      this.transcribeAudio()
    }
  }
  
  async transcribeAudio() {
    // Send the audio to the server for transcription using OpenAI Whisper API
    this.recordingStatusTarget.textContent = 'Transcribing audio...'
    
    try {
      // Get the audio data from the form
      const audioData = document.getElementById('transcription_audio_data').value
      console.log(`Sending audio data for transcription, length: ${audioData.length} characters`)
      
      // Create a FormData object to send to the server
      const formData = new FormData()
      formData.append('audio_data', audioData)
      
      // Log that we're about to send the request
      console.log('Sending transcription request to server...')
      
      // Send the audio data to the server for transcription
      const response = await fetch('/transcription/transcribe', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: formData
      })
      
      console.log(`Received response with status: ${response.status}`)
      
      if (!response.ok) {
        const errorText = await response.text()
        console.error('Error response:', errorText)
        throw new Error(`Transcription failed with status ${response.status}: ${errorText}`)
      }
      
      const result = await response.json()
      console.log('Transcription result:', result)
      
      if (result.error) {
        throw new Error(result.error)
      }
      
      // Update the form and display with the transcribed text
      const textContentInput = document.getElementById('transcription_text_content')
      textContentInput.value = result.text
      this.transcriptionTextTarget.textContent = result.text
      this.transcriptionFormTarget.classList.remove('hidden')
      
      console.log('Form updated with transcribed text')
      console.log('Text content input value:', textContentInput.value)
      
      // Add an event listener to the form to ensure audio data is included when the form is submitted
      this.transcriptionFormTarget.addEventListener('submit', this.ensureAudioDataIncluded.bind(this), { once: true })
      
      this.recordingStatusTarget.textContent = 'Transcription complete. You can now save and analyze the grammar.'
    } catch (error) {
      console.error('Error during transcription:', error)
      this.recordingStatusTarget.textContent = `Error: ${error.message}. Please try again.`
    }
  }

  // Ensure audio data is included in the form submission
  ensureAudioDataIncluded(event) {
    // Get the stored audio data
    const audioData = this.transcriptionFormTarget.dataset.audioData
    
    if (audioData) {
      console.log('Adding audio data to form submission')
      const audioDataInput = document.getElementById('transcription_audio_data')
      
      // Always restore from saved data to ensure we have the complete audio data
      console.log('Ensuring audio data is included in form submission')
      audioDataInput.value = audioData
      
      // Log the data being submitted
      console.log(`Form submission audio data length: ${audioDataInput.value.length} characters`)
      console.log(`Audio MIME type: ${this.transcriptionFormTarget.dataset.audioMimeType || 'unknown'}`)
      
      // Add a hidden field with the MIME type if it exists
      if (this.transcriptionFormTarget.dataset.audioMimeType) {
        let mimeTypeInput = document.getElementById('audio_mime_type')
        if (!mimeTypeInput) {
          mimeTypeInput = document.createElement('input')
          mimeTypeInput.type = 'hidden'
          mimeTypeInput.id = 'audio_mime_type'
          mimeTypeInput.name = 'audio_mime_type'
          this.transcriptionFormTarget.appendChild(mimeTypeInput)
        }
        mimeTypeInput.value = this.transcriptionFormTarget.dataset.audioMimeType
      }
    } else {
      console.warn('No audio data found for form submission')
    }
  }
}
