class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def configure_permitted_parameters
    # Allow nested notification_preferences hash with specific keys
    devise_parameter_sanitizer.permit(:sign_up, keys: [
      :name,
      { notification_preferences: [ :email_updates, :feature_announcements, :practice_reminders, :account_alerts ] }
    ])

    devise_parameter_sanitizer.permit(:account_update, keys: [
      :name,
      { notification_preferences: [ :email_updates, :feature_announcements, :practice_reminders, :account_alerts ] }
    ])
  end

  # Check if user is signed in or has a valid trial session
  def check_user_registration
    return if user_signed_in?
    return if trial_session_valid?

    # Trial expired or not started - prompt user to sign in
    flash[:alert] = "Your trial period has ended. Please sign in or register to continue using all features."
    redirect_to new_user_registration_path
  end

  # Check if the user's trial session is valid (within 2 minutes)
  def trial_session_valid?
    # Initialize trial start time if not set
    if session[:trial_started_at].nil?
      session[:trial_started_at] = Time.current.to_i
      return true
    end

    # Check if trial period (2 minutes) has expired
    trial_start_time = Time.at(session[:trial_started_at])
    trial_duration = 2.minutes
    trial_end_time = trial_start_time + trial_duration

    if Time.current < trial_end_time
      # Trial still valid
      flash.now[:notice] = "Sign in to continue after trial ends."
      return true
    end

    # Trial has expired
    false
  end
end
