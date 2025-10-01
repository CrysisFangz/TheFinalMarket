source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2", ">= 8.0.2.1"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
gem "bootstrap", "~> 5.3.3"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
gem "ransack"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
# For other platforms, this gem is optional.
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end

# Authorization
gem 'pundit', '~> 2.3'

# View components for reusable UI elements
gem 'view_component', '~> 4.0'

# PWA and offline support
gem 'web-push', '~> 3.0'
gem 'redis', '~> 5.0'

# Better form handling with Turbo
gem 'turbo_boost-streams'

# For nested forms and dynamic form handling
gem 'cocoon', '~> 1.2'

# For better enum handling
gem 'enumerize', '~> 2.7'

# For handling money
gem 'money-rails', '~> 1.15'

# For pagination
gem 'pagy', '~> 6.2'

# For scheduling recurring jobs
gem 'whenever', '~> 1.0', require: false

# Payment processing
gem 'square.rb', '~> 42.0'  # Square's official Ruby SDK
gem 'jwt', '~> 2.7'         # For webhook verification

# For secure key management
gem 'encrypted_strings', '~> 0.3'

# For background job processing with retries
gem 'sidekiq', '~> 7.2'
gem 'sidekiq-cron', '~> 1.10'
gem "dartsass-rails", "~> 0.5.1"

gem "elasticsearch-model", "~> 8.0"
gem "elasticsearch-rails", "~> 8.0"
