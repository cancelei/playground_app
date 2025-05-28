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
    navigator.mediaDevices.getUserMedia({ audio: true })
      .then(stream => {
        this.mediaRecorder = new MediaRecorder(stream)
        this.audioChunks = []
        
        this.mediaRecorder.addEventListener('dataavailable', event => {
          this.audioChunks.push(event.data)
        })
        
        this.mediaRecorder.addEventListener('stop', () => this.processRecording())
        
        this.mediaRecorder.start()
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
    this.audioBlob = new Blob(this.audioChunks, { type: 'audio/webm' })
    this.audioUrl = URL.createObjectURL(this.audioBlob)
    
    // Log blob size
    console.log(`Audio blob size: ${this.audioBlob.size} bytes`)
    
    // Set the audio player source
    this.audioPlayerTarget.src = this.audioUrl
    this.audioPreviewTarget.classList.remove('hidden')
    
    // Convert blob to base64 for form submission
    const reader = new FileReader()
    reader.readAsDataURL(this.audioBlob)
    reader.onloadend = () => {
      const base64data = reader.result
      console.log(`Base64 data length: ${base64data.length} characters`)
      
      // Store the audio data in the form
      const audioDataInput = document.getElementById('transcription_audio_data')
      audioDataInput.value = base64data
      
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
      
      this.recordingStatusTarget.textContent = 'Transcription complete. You can now save and analyze the grammar.'
    } catch (error) {
      console.error('Error during transcription:', error)
      this.recordingStatusTarget.textContent = `Error: ${error.message}. Please try again.`
    }
  }
}
