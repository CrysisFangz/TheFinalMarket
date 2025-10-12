# frozen_string_literal: true

# Environment Variables Documentation and Validation
# This file documents all required environment variables for TheFinalMarket

module EnvironmentVariables
  # Database Configuration
  # DATABASE_HOST - PostgreSQL host (default: localhost)
  # DATABASE_USERNAME - PostgreSQL username (default: postgres)
  # DATABASE_PASSWORD - PostgreSQL password (REQUIRED in production)
  # THE_FINAL_MARKET_DATABASE_PASSWORD - Production database password (REQUIRED in production)

  # Payment Processing (Square)
  # SQUARE_ACCESS_TOKEN - Square API access token (REQUIRED for payment processing)
  # SQUARE_LOCATION_ID - Square location ID (REQUIRED for payment processing)
  # SQUARE_WEBHOOK_SIGNATURE_KEY - Square webhook signature verification key (REQUIRED)

  # Search (Elasticsearch)
  # ELASTICSEARCH_URL - Elasticsearch cluster URL (default: http://localhost:9200)

  # Background Jobs (Sidekiq/Redis)
  # REDIS_URL - Redis connection URL (default: redis://localhost:6379/1)

  # Email Configuration
  # SMTP_ADDRESS - SMTP server address
  # SMTP_PORT - SMTP server port
  # SMTP_USERNAME - SMTP authentication username
  # SMTP_PASSWORD - SMTP authentication password
  # SMTP_DOMAIN - SMTP domain

  # Third-party APIs (Optional)
  # AMAZON_API_KEY - Amazon Product Advertising API key
  # EBAY_API_KEY - eBay API key
  # GOOGLE_TRANSLATE_API_KEY - Google Translate API key
  # DEEPL_API_KEY - DeepL translation API key
  # FIXER_API_KEY - Fixer.io currency exchange API key
  # OPENEXCHANGERATES_API_KEY - Open Exchange Rates API key
  # CURRENCYAPI_KEY - CurrencyAPI key

  # Security
  # SECRET_KEY_BASE - Rails secret key base (auto-generated, but should be set in production)

  # Application Configuration
  # RAILS_ENV - Rails environment (development, test, production)
  # RAILS_MAX_THREADS - Maximum number of threads (default: 5)
  # PORT - Application port (default: 3000)
  # RAILS_SERVE_STATIC_FILES - Serve static files in production (true/false)
  # RAILS_LOG_TO_STDOUT - Log to stdout (true/false)

  # Validate critical environment variables in production
  if Rails.env.production?
    required_vars = %w[
      THE_FINAL_MARKET_DATABASE_PASSWORD
      SECRET_KEY_BASE
      SQUARE_ACCESS_TOKEN
      SQUARE_LOCATION_ID
      SQUARE_WEBHOOK_SIGNATURE_KEY
    ]

    missing_vars = required_vars.select { |var| ENV[var].blank? }

    if missing_vars.any?
      error_message = <<~ERROR
        ⚠️  CRITICAL: Missing required environment variables in production:
        #{missing_vars.map { |var| "  - #{var}" }.join("\n")}

        Please set these variables before starting the application.
        See config/initializers/environment_variables.rb for documentation.
      ERROR

      Rails.logger.error(error_message)
      # Uncomment the line below to enforce strict validation (will prevent app from starting)
      # raise error_message
    end
  end
end