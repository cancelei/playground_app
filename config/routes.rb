Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # OpenAI Realtime API routes
  get "realtime", to: "realtime#index"
  post "realtime/session", to: "realtime#create_session"
  post "realtime/sdp_exchange", to: "realtime#sdp_exchange"
  get "realtime/websocket", to: "realtime#websocket"
  get "realtime/transcription", to: "realtime#transcription"
  post "realtime/process_audio", to: "realtime#process_audio"
  post "realtime/conversation_turns", to: "realtime#create_conversation_turn"

  # Defines the root path route ("/")
  root "realtime#index"
end
