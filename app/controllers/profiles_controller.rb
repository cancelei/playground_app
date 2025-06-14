class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
  end

  def update_notification_preferences
    @user = current_user

    if @user.update(notification_preferences_params)
      redirect_to profile_path, notice: "Notification preferences updated successfully."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def notification_preferences_params
    params.require(:user).permit(notification_preferences: [ :email_updates, :feature_announcements, :practice_reminders ])
  end
end
