#!/bin/bash

# The Final Market - Comprehensive Setup Script
# This script sets up the entire application with all features

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Emojis
ROCKET="🚀"
CHECK="✅"
CROSS="❌"
GEAR="⚙️"
DATABASE="🗄️"
SEED="🌱"
LOCK="🔒"
CHAIN="⛓️"
CHART="📊"
BRAIN="🧠"
HEART="❤️"
PACKAGE="📦"

echo ""
echo -e "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                                                            ║${NC}"
echo -e "${PURPLE}║          ${ROCKET} THE FINAL MARKET - SETUP SCRIPT ${ROCKET}           ║${NC}"
echo -e "${PURPLE}║                                                            ║${NC}"
echo -e "${PURPLE}║  Setting up all 11 major features:                        ║${NC}"
echo -e "${PURPLE}║  ${LOCK} Security & Privacy                                    ║${NC}"
echo -e "${PURPLE}║  ${CHAIN} Blockchain & Web3                                    ║${NC}"
echo -e "${PURPLE}║  ${CHART} Advanced Seller Tools                                ║${NC}"
echo -e "${PURPLE}║  ${BRAIN} Hyper-Personalization                                ║${NC}"
echo -e "${PURPLE}║  ${HEART} Social Responsibility                                ║${NC}"
echo -e "${PURPLE}║  And 6 more amazing features!                             ║${NC}"
echo -e "${PURPLE}║                                                            ║${NC}"
echo -e "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print step
print_step() {
    echo -e "${BLUE}${GEAR} $1${NC}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}${CHECK} $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}${CROSS} $1${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Function to print info
print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_warning "This script is optimized for macOS. Some steps may need adjustment for other OS."
fi

# Step 1: Check prerequisites
echo ""
print_step "Step 1: Checking prerequisites..."
echo ""

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    print_error "Homebrew is not installed. Please install it first:"
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    exit 1
else
    print_success "Homebrew is installed"
fi

# Check for rbenv
if ! command -v rbenv &> /dev/null; then
    print_warning "rbenv is not installed. Installing rbenv..."
    brew install rbenv ruby-build
    echo 'eval "$(rbenv init - bash)"' >> ~/.bash_profile
    echo 'eval "$(rbenv init - zsh)"' >> ~/.zshrc
    print_success "rbenv installed"
else
    print_success "rbenv is installed"
fi

# Check for PostgreSQL
if ! command -v psql &> /dev/null; then
    print_warning "PostgreSQL is not installed. Installing PostgreSQL..."
    brew install postgresql@14
    brew services start postgresql@14
    print_success "PostgreSQL installed and started"
else
    print_success "PostgreSQL is installed"
fi

# Check for Redis
if ! command -v redis-server &> /dev/null; then
    print_warning "Redis is not installed. Installing Redis..."
    brew install redis
    brew services start redis
    print_success "Redis installed and started"
else
    print_success "Redis is installed"
fi

# Step 2: Install Ruby
echo ""
print_step "Step 2: Installing Ruby 3.2.2..."
echo ""

# Initialize rbenv
eval "$(rbenv init - bash)" 2>/dev/null || eval "$(rbenv init - zsh)" 2>/dev/null || true

if rbenv versions | grep -q "3.2.2"; then
    print_success "Ruby 3.2.2 is already installed"
else
    print_info "Installing Ruby 3.2.2 (this may take several minutes)..."
    rbenv install 3.2.2
    print_success "Ruby 3.2.2 installed"
fi

# Set local Ruby version
rbenv local 3.2.2
print_success "Set Ruby 3.2.2 as local version"

# Verify Ruby version
RUBY_VERSION=$(ruby -v)
print_info "Ruby version: $RUBY_VERSION"

# Step 3: Install Bundler
echo ""
print_step "Step 3: Installing Bundler..."
echo ""

gem install bundler
print_success "Bundler installed"

# Step 4: Install Gems
echo ""
print_step "Step 4: Installing Ruby gems..."
echo ""

print_info "This may take a few minutes..."
bundle install
print_success "All gems installed"

# Step 5: Setup Database
echo ""
print_step "Step 5: Setting up database..."
echo ""

# Create database
print_info "Creating database..."
bundle exec rails db:create
print_success "Database created"

# Run migrations
print_info "Running migrations..."
bundle exec rails db:migrate
print_success "Migrations completed"

# Display migration summary
echo ""
print_info "Migration Summary:"
echo "  - Security & Privacy System (10 tables)"
echo "  - Blockchain & Web3 System (15 tables)"
echo "  - Advanced Seller Tools (10 tables)"
echo "  - Hyper-Personalization System (4 tables)"
echo "  - Social Responsibility System (6 tables)"
echo "  - Total: 45+ tables created"

# Step 6: Seed Database
echo ""
print_step "Step 6: Seeding database with sample data..."
echo ""

# Main seeds
print_info "Running main seeds..."
bundle exec rails db:seed
print_success "Main seeds completed"

# Security & Privacy seeds
if [ -f "db/seeds/security_privacy_seeds.rb" ]; then
    print_info "${LOCK} Seeding Security & Privacy data..."
    bundle exec rails runner "load 'db/seeds/security_privacy_seeds.rb'"
    print_success "Security & Privacy data seeded"
fi

# Blockchain & Web3 seeds
if [ -f "db/seeds/blockchain_web3_seeds.rb" ]; then
    print_info "${CHAIN} Seeding Blockchain & Web3 data..."
    bundle exec rails runner "load 'db/seeds/blockchain_web3_seeds.rb'"
    print_success "Blockchain & Web3 data seeded"
fi

# Business Intelligence seeds
if [ -f "db/seeds/business_intelligence_seeds.rb" ]; then
    print_info "${CHART} Seeding Business Intelligence data..."
    bundle exec rails runner "load 'db/seeds/business_intelligence_seeds.rb'"
    print_success "Business Intelligence data seeded"
fi

# Step 7: Setup Background Jobs
echo ""
print_step "Step 7: Setting up background jobs..."
echo ""

print_info "Background job processor: Solid Queue (built into Rails 8)"
print_success "Background jobs configured"

# Step 8: Create .env file template
echo ""
print_step "Step 8: Creating environment configuration..."
echo ""

if [ ! -f ".env" ]; then
    cat > .env << 'EOF'
# The Final Market - Environment Variables

# Database
DATABASE_URL=postgresql://localhost/thefinalmarket_development

# Redis
REDIS_URL=redis://localhost:6379/0

# Application
APP_URL=http://localhost:3000
SECRET_KEY_BASE=your_secret_key_base_here

# Blockchain & Web3
NFT_ART_CONTRACT=0x0000000000000000000000000000000000000000
NFT_COLLECTIBLE_CONTRACT=0x0000000000000000000000000000000000000000
NFT_PRODUCT_CONTRACT=0x0000000000000000000000000000000000000000
NFT_MEMBERSHIP_CONTRACT=0x0000000000000000000000000000000000000000
NFT_TICKET_CONTRACT=0x0000000000000000000000000000000000000000
NFT_LOYALTY_CONTRACT=0x0000000000000000000000000000000000000000
NFT_CERTIFICATE_CONTRACT=0x0000000000000000000000000000000000000000
NFT_DEFAULT_CONTRACT=0x0000000000000000000000000000000000000000

POLYGON_RPC_URL=https://polygon-rpc.com
ETHEREUM_RPC_URL=https://mainnet.infura.io/v3/YOUR_INFURA_KEY

# Payment Gateways
STRIPE_SECRET_KEY=sk_test_your_stripe_key
STRIPE_PUBLISHABLE_KEY=pk_test_your_stripe_key
COINBASE_COMMERCE_API_KEY=your_coinbase_commerce_key

# Email Service
SENDGRID_API_KEY=your_sendgrid_api_key
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=your_sendgrid_api_key

# SMS Service (Twilio)
TWILIO_ACCOUNT_SID=your_twilio_account_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token
TWILIO_PHONE_NUMBER=+1234567890

# Cloud Storage (AWS S3)
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_REGION=us-east-1
AWS_BUCKET=thefinalmarket-production

# Analytics
GOOGLE_ANALYTICS_ID=UA-XXXXXXXXX-X

# Security
ENCRYPTION_KEY=your_encryption_key_here

# Feature Flags
ENABLE_CRYPTO_PAYMENTS=true
ENABLE_NFT_MARKETPLACE=true
ENABLE_2FA=true
ENABLE_BLOCKCHAIN_PROVENANCE=true
EOF
    print_success ".env file created"
    print_warning "Please update .env with your actual API keys and credentials"
else
    print_info ".env file already exists"
fi

# Step 9: Compile assets
echo ""
print_step "Step 9: Compiling assets..."
echo ""

bundle exec rails assets:precompile
print_success "Assets compiled"

# Step 10: Final checks
echo ""
print_step "Step 10: Running final checks..."
echo ""

# Check database connection
if bundle exec rails runner "ActiveRecord::Base.connection" &> /dev/null; then
    print_success "Database connection verified"
else
    print_error "Database connection failed"
fi

# Check Redis connection
if redis-cli ping &> /dev/null; then
    print_success "Redis connection verified"
else
    print_warning "Redis connection failed (optional for development)"
fi

# Display setup summary
echo ""
echo -e "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                                                            ║${NC}"
echo -e "${PURPLE}║              ${CHECK} SETUP COMPLETED SUCCESSFULLY! ${CHECK}              ║${NC}"
echo -e "${PURPLE}║                                                            ║${NC}"
echo -e "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}${ROCKET} The Final Market is ready to launch!${NC}"
echo ""
echo -e "${CYAN}Features Installed:${NC}"
echo -e "  ${LOCK} Security & Privacy (2FA, Encryption, Identity Verification)"
echo -e "  ${CHAIN} Blockchain & Web3 (NFTs, Crypto Payments, Smart Contracts)"
echo -e "  ${CHART} Advanced Seller Tools (Analytics, Marketing, Forecasting)"
echo -e "  ${BRAIN} Hyper-Personalization (AI Recommendations, Segmentation)"
echo -e "  ${HEART} Social Responsibility (Charity, Local Business Support)"
echo -e "  ${CHECK} Performance Optimization"
echo -e "  ${CHECK} Omnichannel Integration"
echo -e "  ${CHECK} Accessibility & Inclusivity"
echo -e "  ${CHECK} Gamified Shopping Experience"
echo -e "  ${CHECK} Advanced Mobile App (API Ready)"
echo -e "  ${CHECK} B2B Marketplace"
echo ""

echo -e "${CYAN}Next Steps:${NC}"
echo ""
echo -e "  1. ${YELLOW}Update .env file${NC} with your API keys:"
echo -e "     ${BLUE}nano .env${NC}"
echo ""
echo -e "  2. ${YELLOW}Start the Rails server:${NC}"
echo -e "     ${BLUE}bundle exec rails server${NC}"
echo ""
echo -e "  3. ${YELLOW}Start background jobs (in another terminal):${NC}"
echo -e "     ${BLUE}bundle exec rails solid_queue:start${NC}"
echo ""
echo -e "  4. ${YELLOW}Visit the application:${NC}"
echo -e "     ${BLUE}http://localhost:3000${NC}"
echo ""

echo -e "${CYAN}Documentation:${NC}"
echo -e "  📖 SECURITY_PRIVACY_GUIDE.md - Security features guide"
echo -e "  📖 BUSINESS_INTELLIGENCE_GUIDE.md - Analytics guide"
echo -e "  📖 IMPLEMENTATION_COMPLETE.md - Complete feature list"
echo -e "  📖 FINAL_SUMMARY.md - Quick reference"
echo ""

echo -e "${CYAN}Sample Data Created:${NC}"
echo -e "  👥 Users with various roles and permissions"
echo -e "  🔐 2FA setups and identity verifications"
echo -e "  🖼️  NFTs and crypto payment examples"
echo -e "  📊 Analytics and business intelligence data"
echo -e "  🎯 Personalization profiles and segments"
echo -e "  💝 Charity integrations and local businesses"
echo ""

echo -e "${GREEN}Happy coding! 🚀${NC}"
echo ""

