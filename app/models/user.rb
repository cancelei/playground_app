class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :lockable, :confirmable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :trackable, :timeoutable

  # Set timeout for user sessions (30 minutes of inactivity)
  # This is separate from the "remember me" functionality
  devise :timeoutable, timeout_in: 30.minutes

  # Set default notification preferences
  before_create :set_default_notification_preferences

  # Send welcome email when user is created
  after_create :send_welcome_email

  # Validate name presence
  validates :name, presence: true

  # No longer needed since we removed confirmation

  # Check if user is at risk of deletion due to inactivity
  def inactive?
    last_sign_in_at.present? && last_sign_in_at < 25.days.ago
  end

  # Days remaining before account deletion due to inactivity
  def days_until_deletion
    return nil unless inactive?

    deletion_date = last_sign_in_at + 30.days
    days = (deletion_date.to_date - Date.current).to_i
    days.positive? ? days : 0
  end

  private

  def set_default_notification_preferences
    self.notification_preferences ||= {
      email_updates: true,
      feature_announcements: true,
      practice_reminders: true,
      account_alerts: true # For account deletion warnings
    }
  end

  def send_welcome_email
    UserMailer.welcome_email(self).deliver_later
  end

  # No longer needed as we send welcome email directly after create
end
