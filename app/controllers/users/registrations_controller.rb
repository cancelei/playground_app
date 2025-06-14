class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_sign_up_params, only: [ :create ]
  before_action :configure_account_update_params, only: [ :update ]

  protected

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [
      :name,
      { notification_preferences: [ :email_updates, :feature_announcements, :practice_reminders, :account_alerts ] }
    ])
  end

  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [
      :name,
      :notification_preferences_email_updates,
      :notification_preferences_feature_announcements,
      :notification_preferences_practice_reminders,
      :notification_preferences_account_alerts
    ])
  end

  # Override the update method to handle notification preferences
  def update_resource(resource, params)
    # Extract notification preference params
    notification_params = extract_notification_params(params)

    # Remove notification preference params from the main params
    clean_params = params.except(
      :notification_preferences_email_updates,
      :notification_preferences_feature_announcements,
      :notification_preferences_practice_reminders
    )

    # Update notification preferences if any were provided
    if notification_params.present?
      current_preferences = resource.notification_preferences || {}

      # Update each preference that was included in the form
      notification_params.each do |key, value|
        simple_key = key.to_s.sub("notification_preferences_", "")
        current_preferences[simple_key] = value == "1"
      end

      # Set the updated preferences
      resource.notification_preferences = current_preferences
    end

    # Call the original update_resource method with cleaned params
    super(resource, clean_params)
  end

  private

  def extract_notification_params(params)
    params.select { |key, _| key.to_s.start_with?("notification_preferences_") }
  end
end
