# This job is no longer needed since we removed the confirmation step
# Keeping the file for reference but the job should not be scheduled

class CleanupUnconfirmedUsersJob < ApplicationJob
  queue_as :default

  def perform
    # This job is deprecated as we no longer use the confirmation step
    Rails.logger.info "CleanupUnconfirmedUsersJob is deprecated and will be removed"
  end
end
