#!/bin/bash

# The Final Market - No Docker Deployment Script
# This script deploys without Docker for systems without Docker installed

set -e

echo "🚀 Starting Docker-free deployment of The Final Market..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required environment variables are set
check_environment() {
    print_status "Checking environment configuration..."

    required_vars=(
        "RAILS_MASTER_KEY"
        "DATABASE_URL"
        "REDIS_URL"
        "DOMAIN_NAME"
    )

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            print_error "Required environment variable $var is not set"
            exit 1
        fi
    done

    print_success "Environment configuration validated"
}

# Pre-deployment checks (No Docker)
pre_deployment_checks() {
    print_status "Running pre-deployment checks (No Docker)..."

    # Check if Ruby is available
    if ! ruby -v &> /dev/null; then
        print_error "Ruby is not installed."
        print_status "Please install Ruby 2.7+ to run Rails applications"
        print_status "Visit: https://rubyinstaller.org/ (Windows) or use your package manager"
        exit 1
    fi

    # Check Ruby version
    RUBY_VERSION=$(ruby -e "print RUBY_VERSION")
    print_status "Ruby version: $RUBY_VERSION"

    if [ "$(printf '%s\n' "2.7.0" "$RUBY_VERSION" | sort -V | head -n1)" != "2.7.0" ]; then
        print_warning "Ruby version $RUBY_VERSION is below recommended 2.7+"
        print_warning "Some features may not work optimally"
    fi

    # Check if Bundler is available
    if ! bundle -v &> /dev/null; then
        print_error "Bundler is not installed."
        print_status "Please install Bundler: gem install bundler"
        exit 1
    fi

    print_success "Pre-deployment checks completed"
}

# Install Ruby dependencies
install_dependencies() {
    print_status "Installing Ruby dependencies..."

    # Install gems
    if [ -f "Gemfile" ]; then
        print_status "Installing gems from Gemfile..."
        bundle install
        print_success "Ruby dependencies installed"
    else
        print_warning "No Gemfile found, skipping gem installation"
    fi
}

# Setup database (without Docker)
setup_database() {
    print_status "Setting up database configuration..."

    # Create database configuration if it doesn't exist
    if [ ! -f "config/database.yml" ]; then
        print_warning "Database configuration not found"
        print_status "Please ensure your database is running and accessible"
        print_status "Database URL: $DATABASE_URL"
    else
        print_success "Database configuration found"
    fi

    print_success "Database setup prepared"
}

# Create production startup script (No Docker)
create_startup_script() {
    print_status "Creating production startup script (No Docker)..."

    cat > scripts/start-production-no-docker.sh << 'EOF'
#!/bin/bash
# Production startup script for The Final Market (No Docker)

echo "🏪 Starting The Final Market in production mode (No Docker)..."

# Set environment variables
export RAILS_ENV=production
export RAILS_MASTER_KEY=${RAILS_MASTER_KEY}
export DATABASE_URL=${DATABASE_URL}
export REDIS_URL=${REDIS_URL}
export PORT=3000

# Navigate to application directory
cd "$(dirname "$0")/.."

# Precompile assets for production
echo "Precompiling assets..."
bundle exec rails assets:precompile

# Run database migrations
echo "Running database migrations..."
bundle exec rails db:migrate

# Seed database if needed
echo "Seeding database..."
bundle exec rails db:seed

# Start the application server
echo "Starting Rails server on port $PORT..."
bundle exec rails server -p $PORT -b 0.0.0.0

echo "Application started successfully!"
echo "Access your application at: http://localhost:$PORT"
EOF

    chmod +x scripts/start-production-no-docker.sh
    print_success "Production startup script created"
}

# Main deployment flow (No Docker)
main() {
    echo "🏪 The Final Market - Docker-Free Deployment"
    echo "============================================"
    echo "This deployment runs without Docker dependencies"
    echo ""

    check_environment
    pre_deployment_checks
    install_dependencies
    setup_database
    create_startup_script

    echo ""
    print_success "🎉 Docker-free deployment preparation completed!"
    echo ""
    echo "🌐 To start your application:"
    echo ""
    echo "1. Ensure PostgreSQL is running:"
    echo "   - Windows: Start PostgreSQL service"
    echo "   - macOS: brew services start postgresql"
    echo "   - Linux: sudo systemctl start postgresql"
    echo ""
    echo "2. Ensure Redis is running:"
    echo "   - Windows: Start Redis service"
    echo "   - macOS: brew services start redis"
    echo "   - Linux: sudo systemctl start redis"
    echo ""
    echo "3. Start your application:"
    echo "   ./scripts/start-production-no-docker.sh"
    echo ""
    echo "4. Access your application:"
    echo "   http://localhost:3000"
    echo ""
    echo "📋 Manual deployment steps:"
    echo "   - Set up PostgreSQL and Redis on your system"
    echo "   - Configure environment variables"
    echo "   - Run: bundle install"
    echo "   - Run: bundle exec rails db:migrate"
    echo "   - Run: bundle exec rails db:seed"
    echo "   - Run: bundle exec rails server -p 3000"
    echo ""
    echo "🔧 For Docker deployment (when available):"
    echo "   1. Install Docker Desktop"
    echo "   2. Use: ./scripts/deploy-simple.sh"
}

# Handle script arguments
case "${1:-}" in
    "setup")
        check_environment
        pre_deployment_checks
        install_dependencies
        setup_database
        ;;
    "start")
        create_startup_script
        ;;
    "dependencies")
        install_dependencies
        ;;
    *)
        main
        ;;
esac