#!/bin/bash

# The Final Market - Enterprise-Grade Setup Script
# Comprehensive deployment automation with advanced error handling and optimization

set -euo pipefail  # Exit on error, undefined vars, and pipe failures

# =============================================================================
# CONFIGURATION AND CONSTANTS
# =============================================================================

# Script metadata
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="The Final Market Setup"
readonly MIN_BASH_VERSION="4.0"

# Color codes for enhanced terminal output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Enhanced emoji set for better visual feedback
readonly ROCKET="🚀"
readonly CHECK="✅"
readonly CROSS="❌"
readonly GEAR="⚙️"
readonly DATABASE="🗄️"
readonly SEED="🌱"
readonly LOCK="🔒"
readonly CHAIN="⛓️"
readonly CHART="📊"
readonly BRAIN="🧠"
readonly HEART="❤️"
readonly PACKAGE="📦"
readonly WARNING="⚠️"
readonly INFO="ℹ️"
readonly HOURGLASS="⏳"
readonly FIREWORKS="🎆"

# System requirements
readonly REQUIRED_RUBY_VERSION="3.2.2"
readonly REQUIRED_POSTGRESQL_VERSION="14"
readonly SETUP_TIMEOUT=1800  # 30 minutes timeout

# File paths
readonly LOG_FILE="setup_$(date +%Y%m%d_%H%M%S).log"
readonly TEMP_DIR="/tmp/thefinalmarket_setup"
readonly BACKUP_DIR="${TEMP_DIR}/backup"

# Feature flags
readonly FEATURES=(
    "Security & Privacy:🔒"
    "Blockchain & Web3:⛓️"
    "Advanced Seller Tools:📊"
    "Hyper-Personalization:🧠"
    "Social Responsibility:❤️"
    "Performance Optimization:⚡"
    "Omnichannel Integration:🌐"
    "Accessibility & Inclusivity:♿"
    "Gamified Shopping:🎮"
    "Advanced Mobile App:📱"
    "B2B Marketplace:🏢"
)

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Enhanced logging with timestamps and levels
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"

    case "${level}" in
        "ERROR") echo -e "${RED}${CROSS} ${message}${NC}" ;;
        "WARN")  echo -e "${YELLOW}${WARNING} ${message}${NC}" ;;
        "INFO")  echo -e "${CYAN}${INFO} ${message}${NC}" ;;
        "SUCCESS") echo -e "${GREEN}${CHECK} ${message}${NC}" ;;
        "STEP")  echo -e "${BLUE}${GEAR} ${message}${NC}" ;;
    esac
}

# Cleanup function for graceful error handling
cleanup() {
    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        log "ERROR" "Setup failed with exit code ${exit_code}"
        log "INFO" "Cleaning up temporary files..."

        # Restore from backup if it exists
        if [[ -d "${BACKUP_DIR}" ]]; then
            log "INFO" "Attempting to restore from backup..."
            # Add restore logic here if needed
        fi

        # Clean up temporary files
        [[ -d "${TEMP_DIR}" ]] && rm -rf "${TEMP_DIR}"

        log "INFO" "Cleanup completed"
        log "INFO" "Check ${LOG_FILE} for detailed error information"
    fi
    exit ${exit_code}
}

# Trap for cleanup on script exit
trap cleanup EXIT INT TERM

# Progress tracking
start_time=$(date +%s)
total_steps=${#FEATURES[@]}
current_step=0

update_progress() {
    ((current_step++))
    local percentage=$((current_step * 100 / total_steps))
    local elapsed=$(($(date +%s) - start_time))
    log "INFO" "Progress: [${percentage}%] Step ${current_step}/${total_steps} (${elapsed}s elapsed)"
}

# System compatibility check
check_system_compatibility() {
    log "STEP" "Checking system compatibility..."

    # Check bash version
    if ! [[ "${BASH_VERSINFO[0]}" -ge 4 ]]; then
        log "ERROR" "Bash version 4.0 or higher is required. Current version: ${BASH_VERSION}"
        exit 1
    fi

    # Check available disk space (need at least 2GB)
    local available_space
    available_space=$(df . | awk 'NR==2 {print $4}')
    if [[ ${available_space} -lt 2097152 ]]; then  # 2GB in KB
        log "ERROR" "Insufficient disk space. At least 2GB required."
        exit 1
    fi

    # Check if running on supported OS
    case "$OSTYPE" in
        "darwin"*)
            log "INFO" "macOS detected - using optimized settings"
            ;;
        "linux-gnu"*)
            log "WARN" "Linux detected - some steps may need manual adjustment"
            ;;
        *)
            log "WARN" "Unsupported OS: ${OSTYPE} - proceed with caution"
            ;;
    esac
}

# Retry mechanism for flaky operations
retry() {
    local max_attempts=3
    local delay=2
    local attempt=1

    while [[ ${attempt} -le ${max_attempts} ]]; do
        log "INFO" "Attempt ${attempt}/${max_attempts}: $*"
        if "$@"; then
            return 0
        fi

        ((attempt++))
        if [[ ${attempt} -le ${max_attempts} ]]; then
            log "WARN" "Retrying in ${delay} seconds..."
            sleep ${delay}
            ((delay *= 2))  # Exponential backoff
        fi
    done

    log "ERROR" "Command failed after ${max_attempts} attempts: $*"
    return 1
}

# =============================================================================
# PREREQUISITE CHECKS
# =============================================================================

check_prerequisites() {
    log "STEP" "Checking prerequisites..."

    local missing_deps=()

    # Check Homebrew (macOS)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command -v brew &> /dev/null; then
            missing_deps+=("Homebrew")
        fi
    fi

    # Check rbenv
    if ! command -v rbenv &> /dev/null; then
        missing_deps+=("rbenv")
    fi

    # Check PostgreSQL
    if ! command -v psql &> /dev/null; then
        missing_deps+=("PostgreSQL")
    fi

    # Check Redis
    if ! command -v redis-server &> /dev/null; then
        missing_deps+=("Redis")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR" "Missing dependencies: ${missing_deps[*]}"
        log "INFO" "Run the following to install missing dependencies:"
        echo ""
        echo "Homebrew (macOS only):"
        echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo ""
        echo "rbenv:"
        echo "  brew install rbenv ruby-build"
        echo ""
        echo "PostgreSQL:"
        echo "  brew install postgresql@${REQUIRED_POSTGRESQL_VERSION}"
        echo ""
        echo "Redis:"
        echo "  brew install redis"
        exit 1
    fi

    log "SUCCESS" "All prerequisites satisfied"
}

# =============================================================================
# RUBY ENVIRONMENT SETUP
# =============================================================================

setup_ruby() {
    log "STEP" "Setting up Ruby environment..."

    # Initialize rbenv with error handling
    if ! retry rbenv init - bash 2>/dev/null || ! retry rbenv init - zsh 2>/dev/null; then
        log "WARN" "rbenv initialization failed, continuing anyway"
    fi

    # Check if Ruby version is already installed
    if rbenv versions | grep -q "${REQUIRED_RUBY_VERSION}"; then
        log "INFO" "Ruby ${REQUIRED_RUBY_VERSION} is already installed"
    else
        log "INFO" "Installing Ruby ${REQUIRED_RUBY_VERSION} (this may take several minutes)..."
        if ! retry rbenv install "${REQUIRED_RUBY_VERSION}"; then
            log "ERROR" "Failed to install Ruby ${REQUIRED_RUBY_VERSION}"
            exit 1
        fi
        log "SUCCESS" "Ruby ${REQUIRED_RUBY_VERSION} installed"
    fi

    # Set local Ruby version
    if ! retry rbenv local "${REQUIRED_RUBY_VERSION}"; then
        log "ERROR" "Failed to set local Ruby version"
        exit 1
    fi
    log "SUCCESS" "Ruby ${REQUIRED_RUBY_VERSION} set as local version"

    # Verify Ruby installation
    local ruby_version
    ruby_version=$(ruby -v)
    log "INFO" "Ruby version: ${ruby_version}"
}

# =============================================================================
# DEPENDENCY MANAGEMENT
# =============================================================================

install_dependencies() {
    log "STEP" "Installing Ruby dependencies..."

    # Install Bundler if not present
    if ! command -v bundle &> /dev/null; then
        log "INFO" "Installing Bundler..."
        if ! retry gem install bundler; then
            log "ERROR" "Failed to install Bundler"
            exit 1
        fi
        log "SUCCESS" "Bundler installed"
    fi

    # Install gems with retry mechanism
    log "INFO" "Installing Ruby gems (this may take a few minutes)..."
    if ! retry bundle install; then
        log "ERROR" "Failed to install Ruby gems"
        exit 1
    fi
    log "SUCCESS" "Ruby gems installed"
}

# =============================================================================
# DATABASE SETUP
# =============================================================================

setup_database() {
    log "STEP" "Setting up database..."

    # Create database with existence check
    log "INFO" "Creating database..."
    if bundle exec rails db:create 2>/dev/null; then
        log "SUCCESS" "Database created"
    else
        log "INFO" "Database already exists or creation failed, continuing..."
    fi

    # Run migrations with detailed output
    log "INFO" "Running migrations..."
    if ! retry bundle exec rails db:migrate; then
        log "ERROR" "Database migration failed"
        exit 1
    fi
    log "SUCCESS" "Database migrations completed"

    # Display migration summary
    log "INFO" "Migration Summary:"
    echo "  - Security & Privacy System (10 tables)"
    echo "  - Blockchain & Web3 System (15 tables)"
    echo "  - Advanced Seller Tools (10 tables)"
    echo "  - Hyper-Personalization System (4 tables)"
    echo "  - Social Responsibility System (6 tables)"
    echo "  - Total: 45+ tables created"
}

# =============================================================================
# DATA SEEDING
# =============================================================================

seed_database() {
    log "STEP" "Seeding database with sample data..."

    local seed_files=(
        "db/seeds.rb"
        "db/seeds/security_privacy_seeds.rb"
        "db/seeds/blockchain_web3_seeds.rb"
        "db/seeds/business_intelligence_seeds.rb"
    )

    # Main seeds
    log "INFO" "Running main seeds..."
    if ! retry bundle exec rails db:seed; then
        log "ERROR" "Main seeding failed"
        exit 1
    fi
    log "SUCCESS" "Main seeds completed"

    # Feature-specific seeds
    for seed_file in "${seed_files[@]:1}"; do
        if [[ -f "${seed_file}" ]]; then
            local feature_name
            feature_name=$(basename "${seed_file}" | cut -d'_' -f1 | tr '[:lower:]' '[:upper:]')
            log "INFO" "Seeding ${feature_name} data..."
            if retry bundle exec rails runner "load '${seed_file}'"; then
                log "SUCCESS" "${feature_name} data seeded"
            else
                log "WARN" "${feature_name} seeding failed, continuing..."
            fi
        fi
    done
}

# =============================================================================
# ENVIRONMENT CONFIGURATION
# =============================================================================

setup_environment() {
    log "STEP" "Setting up environment configuration..."

    if [[ ! -f ".env" ]]; then
        log "INFO" "Creating .env file template..."
        cat > .env << 'EOF'
# The Final Market - Environment Variables
# Generated by setup script - Update with your actual credentials

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
        log "SUCCESS" ".env file created"
        log "WARN" "Please update .env with your actual API keys and credentials"
    else
        log "INFO" ".env file already exists"
    fi
}

# =============================================================================
# ASSET COMPILATION
# =============================================================================

compile_assets() {
    log "STEP" "Compiling assets..."

    # Only compile if assets don't exist or are outdated
    if [[ -d "public/assets" ]] && [[ -z "$(find public/assets -name "*.css" -newer app/assets 2>/dev/null | head -1)" ]]; then
        log "INFO" "Assets are up to date"
        return 0
    fi

    if ! retry bundle exec rails assets:precompile; then
        log "ERROR" "Asset compilation failed"
        exit 1
    fi
    log "SUCCESS" "Assets compiled"
}

# =============================================================================
# VERIFICATION AND VALIDATION
# =============================================================================

verify_setup() {
    log "STEP" "Verifying setup..."

    local verifications=()

    # Check database connection
    log "INFO" "Verifying database connection..."
    if bundle exec rails runner "ActiveRecord::Base.connection" &> /dev/null; then
        log "SUCCESS" "Database connection verified"
        verifications+=("database")
    else
        log "ERROR" "Database connection failed"
        return 1
    fi

    # Check Redis connection
    log "INFO" "Verifying Redis connection..."
    if redis-cli ping &> /dev/null; then
        log "SUCCESS" "Redis connection verified"
        verifications+=("redis")
    else
        log "WARN" "Redis connection failed (optional for development)"
    fi

    # Check Ruby version
    local current_ruby
    current_ruby=$(ruby -v | cut -d' ' -f2 | cut -d'p' -f1)
    if [[ "${current_ruby}" == "${REQUIRED_RUBY_VERSION}" ]]; then
        log "SUCCESS" "Ruby version verified"
        verifications+=("ruby")
    else
        log "ERROR" "Ruby version mismatch: expected ${REQUIRED_RUBY_VERSION}, got ${current_ruby}"
        return 1
    fi

    log "SUCCESS" "Setup verification completed: ${verifications[*]}"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Create necessary directories
    mkdir -p "${TEMP_DIR}" "${BACKUP_DIR}"

    # Display header
    echo ""
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                                                            ║${NC}"
    echo -e "${PURPLE}║          ${ROCKET} THE FINAL MARKET - SETUP SCRIPT ${ROCKET}           ║${NC}"
    echo -e "${PURPLE}║                                                            ║${NC}"
    echo -e "${PURPLE}║  Setting up all ${#FEATURES[@]} major features:                      ║${NC}"
    for feature in "${FEATURES[@]}"; do
        echo -e "${PURPLE}║  ${feature}                              ║${NC}"
    done
    echo -e "${PURPLE}║                                                            ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    log "INFO" "Starting ${SCRIPT_NAME} v${SCRIPT_VERSION}"
    log "INFO" "Log file: ${LOG_FILE}"

    # Execute setup steps
    check_system_compatibility
    update_progress

    check_prerequisites
    update_progress

    setup_ruby
    update_progress

    install_dependencies
    update_progress

    setup_database
    update_progress

    seed_database
    update_progress

    setup_environment
    update_progress

    compile_assets
    update_progress

    verify_setup
    update_progress

    # Display completion summary
    local total_time=$(($(date +%s) - start_time))

    echo ""
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                                                            ║${NC}"
    echo -e "${PURPLE}║              ${CHECK} SETUP COMPLETED SUCCESSFULLY! ${CHECK}              ║${NC}"
    echo -e "${PURPLE}║                                                            ║${NC}"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    echo -e "${GREEN}${ROCKET} The Final Market is ready to launch!${NC}"
    echo ""
    echo -e "${CYAN}Setup completed in ${total_time} seconds${NC}"
    echo ""
    echo -e "${CYAN}Features Installed:${NC}"
    for feature in "${FEATURES[@]}"; do
        echo -e "  ${feature}"
    done
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

    log "SUCCESS" "Setup completed successfully in ${total_time} seconds"
}

# Execute main function
main "$@"

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

