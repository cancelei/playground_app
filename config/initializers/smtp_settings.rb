# Configure ActionMailer to use SMTP with environment variables
Rails.application.config.action_mailer.delivery_method = :smtp
Rails.application.config.action_mailer.smtp_settings = {
  address: ENV.fetch("SMTP_ADDRESS", "smtp.acumbamail.com"),
  port: ENV.fetch("SMTP_PORT", 587).to_i,
  domain: ENV.fetch("SMTP_DOMAIN", "acumbamail.com"),
  user_name: ENV.fetch("SMTP_USERNAME", nil),
  password: ENV.fetch("SMTP_PASSWORD", nil),
  authentication: ENV.fetch("SMTP_AUTHENTICATION", "plain").to_sym,
  enable_starttls_auto: ENV.fetch("SMTP_ENABLE_STARTTLS_AUTO", "true") == "true"
}
