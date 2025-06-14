# This initializer contains fixes for asset precompilation in Docker builds
# It detects when we're in asset precompilation mode and disables features that might cause issues

# Detect if we're in asset precompilation mode
is_precompiling = defined?(Sprockets::Rails::Task) &&
                  File.basename($0) == "rake" &&
                  (ARGV.include?("assets:precompile") || ARGV.include?("assets:clobber"))

if is_precompiling || ENV["SECRET_KEY_BASE_DUMMY"].present?
  Rails.logger.info "Running in asset precompilation mode - disabling certain features"

  # Disable features that might cause issues during precompilation

  # 1. Disable database connections if possible
  Rails.application.config.middleware.delete(ActiveRecord::Migration::CheckPending) if defined?(ActiveRecord::Migration::CheckPending)

  # 2. Stub out SolidQueue if it's being loaded
  unless defined?(SolidQueue)
    module SolidQueue
      def self.schedule(*args)
        # No-op during precompilation
      end
    end
  end

  # 3. Set dummy values for required environment variables
  ENV["APPLICATION_HOST"] ||= "localhost"
  ENV["SMTP_ADDRESS"] ||= "localhost"
  ENV["SMTP_PORT"] ||= "25"
  ENV["SMTP_DOMAIN"] ||= "localhost"
  ENV["SMTP_USERNAME"] ||= "dummy"
  ENV["SMTP_PASSWORD"] ||= "dummy"
end
