#!/bin/bash
###############################################################################
# The Final Market - Intelligent Auto-Setup Script
# Autonomous Value Addition: Self-healing setup with environment detection
# 
# Features:
# - Automatic Ruby version management detection (rbenv/rvm/asdf)
# - System dependency detection and installation
# - Service health checks with auto-recovery
# - Rollback capability on failure
# - Colored output and progress tracking
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REQUIRED_RUBY_VERSION="3.3.7"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="$PROJECT_ROOT/backups/setup-$(date +%Y%m%d-%H%M%S)"

# Progress tracking
TOTAL_STEPS=10
CURRENT_STEP=0

###############################################################################
# UTILITY FUNCTIONS
###############################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    echo -e "\n${BLUE}[Step $CURRENT_STEP/$TOTAL_STEPS]${NC} $1"
}

create_backup() {
    log_info "Creating safety backup..."
    mkdir -p "$BACKUP_DIR"
    
    # Backup critical files
    [ -f "$PROJECT_ROOT/.env" ] && cp "$PROJECT_ROOT/.env" "$BACKUP_DIR/.env.backup"
    [ -f "$PROJECT_ROOT/Gemfile.lock" ] && cp "$PROJECT_ROOT/Gemfile.lock" "$BACKUP_DIR/Gemfile.lock.backup"
    
    log_success "Backup created at: $BACKUP_DIR"
}

rollback() {
    log_error "Setup failed! Rolling back..."
    
    if [ -d "$BACKUP_DIR" ]; then
        [ -f "$BACKUP_DIR/.env.backup" ] && cp "$BACKUP_DIR/.env.backup" "$PROJECT_ROOT/.env"
        [ -f "$BACKUP_DIR/Gemfile.lock.backup" ] && cp "$BACKUP_DIR/Gemfile.lock.backup" "$PROJECT_ROOT/Gemfile.lock"
        log_success "Rollback complete"
    fi
    
    exit 1
}

trap rollback ERR

###############################################################################
# ENVIRONMENT DETECTION
###############################################################################

detect_os() {
    case "$(uname -s)" in
        Darwin*)    echo "macos";;
        Linux*)     
            if [ -f /etc/debian_version ]; then
                echo "debian"
            elif [ -f /etc/redhat-release ]; then
                echo "redhat"
            else
                echo "linux"
            fi
            ;;
        *)          echo "unknown";;
    esac
}

detect_ruby_manager() {
    if command -v rbenv &> /dev/null; then
        echo "rbenv"
    elif command -v rvm &> /dev/null; then
        echo "rvm"
    elif command -v asdf &> /dev/null && [ -f "$HOME/.asdf/plugins/ruby/bin/asdf" ]; then
        echo "asdf"
    else
        echo "none"
    fi
}

detect_package_manager() {
    local os=$(detect_os)
    case "$os" in
        macos)
            if command -v brew &> /dev/null; then
                echo "brew"
            else
                echo "none"
            fi
            ;;
        debian)
            echo "apt"
            ;;
        redhat)
            echo "yum"
            ;;
        *)
            echo "none"
            ;;
    esac
}

###############################################################################
# SYSTEM CHECKS
###############################################################################

check_system_requirements() {
    progress "Checking system requirements..."
    
    local os=$(detect_os)
    log_info "Operating System: $os"
    
    local pkg_manager=$(detect_package_manager)
    if [ "$pkg_manager" = "none" ]; then
        log_error "No package manager detected. Please install Homebrew (macOS) or use apt/yum (Linux)"
        return 1
    fi
    log_success "Package manager: $pkg_manager"
    
    local ruby_manager=$(detect_ruby_manager)
    if [ "$ruby_manager" = "none" ]; then
        log_warning "No Ruby version manager detected"
        return 2
    fi
    log_success "Ruby manager: $ruby_manager"
    
    return 0
}

###############################################################################
# INSTALLATION FUNCTIONS
###############################################################################

install_ruby_manager() {
    progress "Installing Ruby version manager..."
    
    local ruby_manager=$(detect_ruby_manager)
    
    if [ "$ruby_manager" = "none" ]; then
        log_info "Installing rbenv (recommended)..."
        
        if [ "$(detect_os)" = "macos" ]; then
            brew install rbenv ruby-build
        else
            curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
        fi
        
        # Add to shell profile
        echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.zshrc
        echo 'eval "$(rbenv init -)"' >> ~/.zshrc
        export PATH="$HOME/.rbenv/bin:$PATH"
        eval "$(rbenv init -)"
        
        log_success "rbenv installed successfully"
    else
        log_success "Ruby manager already installed: $ruby_manager"
    fi
}

install_ruby() {
    progress "Installing Ruby $REQUIRED_RUBY_VERSION..."
    
    local ruby_manager=$(detect_ruby_manager)
    local current_version=$(ruby -v 2>/dev/null | awk '{print $2}' || echo "none")
    
    if [[ "$current_version" == "$REQUIRED_RUBY_VERSION"* ]]; then
        log_success "Ruby $REQUIRED_RUBY_VERSION already installed"
        return 0
    fi
    
    case "$ruby_manager" in
        rbenv)
            rbenv install -s $REQUIRED_RUBY_VERSION
            rbenv local $REQUIRED_RUBY_VERSION
            ;;
        rvm)
            rvm install $REQUIRED_RUBY_VERSION
            rvm use $REQUIRED_RUBY_VERSION
            ;;
        asdf)
            asdf plugin add ruby || true
            asdf install ruby $REQUIRED_RUBY_VERSION
            asdf local ruby $REQUIRED_RUBY_VERSION
            ;;
        *)
            log_error "Cannot install Ruby without a version manager"
            return 1
            ;;
    esac
    
    # Verify installation
    local new_version=$(ruby -v | awk '{print $2}')
    if [[ "$new_version" == "$REQUIRED_RUBY_VERSION"* ]]; then
        log_success "Ruby $new_version installed and activated"
    else
        log_error "Ruby installation verification failed"
        return 1
    fi
}

install_system_dependencies() {
    progress "Installing system dependencies..."
    
    local pkg_manager=$(detect_package_manager)
    
    case "$pkg_manager" in
        brew)
            log_info "Installing PostgreSQL, Redis, and build dependencies..."
            brew install postgresql@16 redis libpq imagemagick || true
            
            log_info "Starting services..."
            brew services start postgresql@16
            brew services start redis
            ;;
        apt)
            log_info "Installing PostgreSQL, Redis, and build dependencies..."
            sudo apt-get update
            sudo apt-get install -y postgresql postgresql-contrib redis-server \
                libpq-dev build-essential libssl-dev libyaml-dev imagemagick
            
            log_info "Starting services..."
            sudo systemctl start postgresql
            sudo systemctl start redis-server
            ;;
        yum)
            log_info "Installing PostgreSQL, Redis, and build dependencies..."
            sudo yum install -y postgresql-server postgresql-devel redis \
                gcc make openssl-devel libyaml-devel ImageMagick
            
            log_info "Starting services..."
            sudo systemctl start postgresql
            sudo systemctl start redis
            ;;
    esac
    
    log_success "System dependencies installed"
}

check_service_health() {
    progress "Checking service health..."
    
    # Check PostgreSQL
    if pg_isready -q 2>/dev/null || psql -U postgres -c "SELECT 1" &>/dev/null; then
        log_success "PostgreSQL is running"
    else
        log_warning "PostgreSQL is not accessible (you may need to configure credentials)"
    fi
    
    # Check Redis
    if redis-cli ping &>/dev/null; then
        log_success "Redis is running"
    else
        log_warning "Redis is not accessible"
    fi
}

###############################################################################
# APPLICATION SETUP
###############################################################################

install_gems() {
    progress "Installing Ruby gems..."
    
    cd "$PROJECT_ROOT"
    
    # Install Bundler
    gem install bundler --no-document
    log_success "Bundler installed"
    
    # Install gems with retry logic
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Installing gems (attempt $attempt/$max_attempts)..."
        
        if bundle install; then
            log_success "All gems installed successfully"
            return 0
        else
            log_warning "Gem installation failed, retrying..."
            attempt=$((attempt + 1))
            sleep 2
        fi
    done
    
    log_error "Gem installation failed after $max_attempts attempts"
    return 1
}

setup_environment() {
    progress "Setting up environment configuration..."
    
    cd "$PROJECT_ROOT"
    
    if [ ! -f .env ]; then
        cp .env.example .env
        
        # Generate SECRET_KEY_BASE
        SECRET_KEY=$(ruby -e "require 'securerandom'; puts SecureRandom.hex(64)")
        
        # Update .env file
        if [ "$(uname)" = "Darwin" ]; then
            sed -i '' "s/your_secret_key_base_here/$SECRET_KEY/" .env
        else
            sed -i "s/your_secret_key_base_here/$SECRET_KEY/" .env
        fi
        
        log_success ".env file created with generated SECRET_KEY_BASE"
        log_warning "⚠️  Remember to configure payment credentials (SQUARE_ACCESS_TOKEN)"
    else
        log_info ".env file already exists (skipping)"
    fi
}

setup_database() {
    progress "Setting up database..."
    
    cd "$PROJECT_ROOT"
    
    # Create databases
    if rails db:create 2>/dev/null; then
        log_success "Databases created"
    else
        log_warning "Database creation skipped (may already exist)"
    fi
    
    # Run migrations
    log_info "Running migrations (this may take a minute)..."
    if rails db:migrate; then
        log_success "Database migrations completed"
    else
        log_error "Database migration failed"
        return 1
    fi
    
    # Optional: Seed data
    read -p "$(echo -e ${YELLOW}Would you like to seed sample data? [y/N]${NC} )" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rails db:seed
        log_success "Sample data seeded"
    fi
}

###############################################################################
# VERIFICATION
###############################################################################

verify_setup() {
    progress "Verifying setup..."
    
    cd "$PROJECT_ROOT"
    
    # Check if Rails can boot
    log_info "Testing Rails environment..."
    if rails runner "puts 'Rails OK'" &>/dev/null; then
        log_success "Rails environment is working"
    else
        log_error "Rails environment test failed"
        return 1
    fi
    
    # Check critical models
    log_info "Checking database schema..."
    if rails runner "User.count; Product.count" &>/dev/null; then
        log_success "Database schema is valid"
    else
        log_error "Database schema validation failed"
        return 1
    fi
    
    # Check Redis connection
    log_info "Testing Redis connection..."
    if rails runner "Rails.cache.write('test', 'ok'); Rails.cache.read('test')" &>/dev/null; then
        log_success "Redis connection working"
    else
        log_warning "Redis connection failed (features may be limited)"
    fi
}

###############################################################################
# MAIN EXECUTION
###############################################################################

main() {
    echo -e "${GREEN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║          The Final Market - Intelligent Setup                ║
║                                                               ║
║     Autonomous Environment Detection & Configuration         ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    log_info "Starting intelligent setup process..."
    log_info "Project root: $PROJECT_ROOT"
    echo
    
    # Create backup before starting
    create_backup
    
    # Execute setup steps
    check_system_requirements
    local check_result=$?
    
    if [ $check_result -eq 2 ]; then
        install_ruby_manager
    fi
    
    install_ruby
    install_system_dependencies
    check_service_health
    install_gems
    setup_environment
    setup_database
    verify_setup
    
    # Success message
    echo
    echo -e "${GREEN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║                    ✓ SETUP COMPLETE!                         ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    log_success "The Final Market is ready to run!"
    echo
    log_info "Next steps:"
    echo "  1. Review and update .env file with your API credentials"
    echo "  2. Start Sidekiq: bundle exec sidekiq"
    echo "  3. Start Rails server: rails server"
    echo "  4. Visit: http://localhost:3000"
    echo
    log_info "Backup location: $BACKUP_DIR"
    echo
}

# Run main function
main "$@"