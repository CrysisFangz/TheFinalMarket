---
description: Repository Information Overview
alwaysApply: true
---

# The Final Market Information

## Summary
The Final Market is an enterprise-grade e-commerce platform built with Rails 8, featuring comprehensive marketplace functionality including user management, product listings, order processing, payment integration, and advanced features like blockchain integration, AI personalization, and fraud detection.

## Structure
- **app/**: Core application code (models, controllers, views, services)
- **config/**: Application configuration files
- **db/**: Database migrations and schema
- **lib/**: Library code and custom modules
- **public/**: Static assets
- **test/**: Test suite and fixtures
- **vendor/**: Third-party code and dependencies

## Language & Runtime
**Language**: Ruby
**Version**: 3.2.2 (development), 3.3.7 (recommended in README)
**Framework**: Rails 8.0.2
**Build System**: Bundler
**Package Manager**: Bundler (Ruby), npm (JavaScript)

## Dependencies
**Main Dependencies**:
- Rails 8.0.2 - Web framework
- PostgreSQL 16 - Database
- Redis 5.0+ - Caching and background jobs
- Sidekiq 7.3 - Background job processing
- Turbo/Stimulus - Frontend interactivity
- Square.rb - Payment processing
- Elasticsearch - Search functionality
- Rails Event Store - Event sourcing

**Development Dependencies**:
- RSpec/Capybara - Testing
- Rubocop - Code linting
- Solargraph - Code intelligence
- Pry/Debug - Debugging tools

## Build & Installation
```bash
# Install dependencies
bundle install

# Setup database
rails db:create db:migrate db:seed

# Start server
rails server

# Start background workers
bundle exec sidekiq
```

## Docker
**Dockerfile**: Dockerfile
**Image**: the_final_market
**Configuration**: Multi-stage build with Ruby 3.4.1 slim image
**Run Command**:
```bash
docker build -t the_final_market .
docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value> --name the_final_market the_final_market
```

## Testing
**Framework**: Minitest (default), RSpec (available)
**Test Location**: test/ directory
**Naming Convention**: *_test.rb
**Configuration**: test/test_helper.rb
**Run Command**:
```bash
rails test
```

## Main Components
**Models**: 160+ ActiveRecord models for marketplace entities
**Controllers**: 56+ controllers handling request flow
**Services**: Business logic encapsulation
**Background Jobs**: Sidekiq workers for async processing
**API**: REST and GraphQL endpoints
**Frontend**: Bootstrap 5, Stimulus.js, Turbo