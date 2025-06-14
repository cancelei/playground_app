class UserMailer < ApplicationMailer
  default from: "notifications@flukebase.me"

  def welcome_email(user)
    @user = user
    @url = new_user_session_url
    mail(to: @user.email, subject: "Welcome to Playground by Flukebase!")
  end

  def feature_announcement(user, feature_title, feature_description)
    @user = user
    @feature_title = feature_title
    @feature_description = feature_description
    mail(to: @user.email, subject: "New Feature: #{feature_title}")
  end

  def practice_reminder(user)
    @user = user
    @url = transcription_url
    mail(to: @user.email, subject: "Time to practice your language skills!")
  end

  def account_activation_reminder(user)
    @user = user
    @confirmation_url = user_confirmation_url(confirmation_token: @user.confirmation_token)
    @hours_remaining = ((user.created_at + 24.hours - Time.current) / 1.hour).round
    mail(to: @user.email, subject: "Action Required: Activate Your Account")
  end

  def inactivity_warning(user)
    @user = user
    @days_remaining = user.days_until_deletion
    @login_url = new_user_session_url
    mail(to: @user.email, subject: "Account Deletion Warning: Inactivity Detected")
  end

  def account_deletion_notification(user)
    @user = user
    @signup_url = new_user_registration_url
    mail(to: @user.email, subject: "Your Account Has Been Deleted Due to Inactivity")
  end
end
