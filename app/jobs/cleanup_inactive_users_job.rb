class CleanupInactiveUsersJob < ApplicationJob
  queue_as :default

  def perform
    # Find users who haven't logged in for more than 30 days
    inactive_users = User.where("last_sign_in_at < ?", 30.days.ago)

    if inactive_users.any?
      Rails.logger.info "Deleting #{inactive_users.count} inactive users due to 30+ days of inactivity"

      # Optionally send notification emails before deletion
      inactive_users.each do |user|
        UserMailer.account_deletion_notification(user).deliver_now
      end

      inactive_users.destroy_all
    end
  end
end
