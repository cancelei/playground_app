# OpenAI Realtime API Integration for Rails 8

This integration demonstrates how to use the OpenAI Realtime API with Ruby on Rails 8, following the "Solid" stack approach with Hotwire (Turbo + Stimulus) and Tailwind CSS.

## Implementation Overview

The project implements three key ways to interact with the OpenAI Realtime API:

1. **WebRTC Client-Side Integration** - Connect directly from the browser to OpenAI
2. **WebSocket Server-Side Integration** - Connect from your Rails server to OpenAI
3. **Transcription-Only Mode** - Specialized mode for real-time transcription with Voice Activity Detection

Currently, this implementation runs in **simulation mode** to demonstrate the concepts without requiring an active OpenAI API connection. This allows for development and testing of the user interface and application architecture.

## Key Features

- **Speech-to-Speech Conversations** - Demonstrates how to build conversational interfaces
- **Real-time Transcription** - Shows live speech-to-text capabilities with interim results
- **Voice Activity Detection** - Demonstrates automatic detection of speech pauses
- **Cost & Performance Metrics** - Includes monitoring of processing metrics

## Project Structure

- `app/controllers/realtime_controller.rb` - Main controller handling API endpoints
- `app/services/openai_realtime_service.rb` - Service object wrapping the OpenAI API
- `app/javascript/controllers/openai_realtime_controller.js` - Stimulus controller for WebRTC
- `app/javascript/controllers/openai_transcription_controller.js` - Stimulus controller for transcription
- `app/views/realtime/` - Views for the different demos

## Enabling Live API Access

To enable actual API access instead of simulation:

1. Ensure you have a valid OpenAI API key in your `.env` file
2. Update the `OpenaiRealtimeService` to correctly connect to the OpenAI API
3. Modify the JavaScript controllers to remove the simulation code

## Technical Implementation Details

### WebRTC Flow

1. Client requests an ephemeral token from the Rails server
2. Rails server uses the OpenAI API to generate this token
3. Client establishes a direct WebRTC connection to OpenAI using this token
4. Audio is streamed from the user's browser to OpenAI
5. Responses are received directly in the client

### WebSocket Flow

1. Rails server establishes a WebSocket connection to OpenAI
2. Audio data is transferred through this connection
3. Responses come back through the server
4. ActionCable can be used to stream these responses to the client

### Transcription Flow

1. Audio is streamed to the OpenAI transcription model
2. Interim transcription results appear as they're generated
3. Final transcriptions are determined by Voice Activity Detection

## Development Notes

- The OpenAI Realtime API is in beta and may change
- The implementation follows Rails 8's "Solid" stack conventions
- Hotwire (Stimulus) is used for interactive UI components
- Tailwind CSS provides responsive styling

## Requirements

- Ruby 3.2+
- Rails 8.0+
- OpenAI API key with Realtime API access
- Modern browser with WebRTC support
