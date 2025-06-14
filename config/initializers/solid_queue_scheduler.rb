# SolidQueue scheduler configuration
# We've removed the account confirmation step, so we don't need the cleanup job for unconfirmed users

# Skip scheduler during asset precompilation to avoid errors
is_precompiling = defined?(Sprockets::Rails::Task) &&
                  File.basename($0) == "rake" &&
                  (ARGV.include?("assets:precompile") || ARGV.include?("assets:clobber"))

unless is_precompiling || ENV["SECRET_KEY_BASE_DUMMY"].present?
  Rails.application.config.after_initialize do
    # Only run in production or if explicitly enabled in development
    if (Rails.env.production? || ENV["ENABLE_SCHEDULERS"] == "true") && defined?(SolidQueue.schedule)
      # Schedule cleanup of inactive users daily at 4 AM
      SolidQueue.schedule(
        CleanupInactiveUsersJob,
        every: 1.day,
        at: "04:00",
        timezone: "UTC"
      )

      # Schedule inactivity warning emails (sent at 25 days of inactivity)
      SolidQueue.schedule(
        -> {
          # Find users who haven't logged in for 25-26 days (to avoid sending multiple warnings)
          at_risk_users = User.where("last_sign_in_at BETWEEN ? AND ?", 26.days.ago, 25.days.ago)
          at_risk_users.find_each do |user|
            UserMailer.inactivity_warning(user).deliver_later
          end
        },
        every: 1.day,
        at: "05:00",
        timezone: "UTC"
      )
    end
  end
end
