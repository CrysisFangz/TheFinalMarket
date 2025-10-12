#!/bin/bash

# The Final Market - Quick Setup Script
# Minimal setup for development

set -e

echo "🚀 Quick Setup for The Final Market"
echo ""

# Install Ruby 3.2.2
echo "📦 Setting up Ruby 3.2.2..."
if ! rbenv versions | grep -q "3.2.2"; then
    rbenv install 3.2.2
fi
rbenv local 3.2.2
eval "$(rbenv init - bash)" 2>/dev/null || eval "$(rbenv init - zsh)" 2>/dev/null || true

# Install gems
echo "📦 Installing dependencies..."
gem install bundler
bundle install

# Setup database
echo "🗄️  Setting up database..."
bundle exec rails db:create
bundle exec rails db:migrate

# Seed data
echo "🌱 Seeding database..."
bundle exec rails db:seed

# Seed additional data
[ -f "db/seeds/security_privacy_seeds.rb" ] && bundle exec rails runner "load 'db/seeds/security_privacy_seeds.rb'"
[ -f "db/seeds/blockchain_web3_seeds.rb" ] && bundle exec rails runner "load 'db/seeds/blockchain_web3_seeds.rb'"
[ -f "db/seeds/business_intelligence_seeds.rb" ] && bundle exec rails runner "load 'db/seeds/business_intelligence_seeds.rb'"

echo ""
echo "✅ Setup complete!"
echo ""
echo "Start the server:"
echo "  bundle exec rails server"
echo ""

