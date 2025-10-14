#!/bin/bash

# The Final Market - Simple Deployment Script (No Kamal Required)
# This script provides basic deployment without Kamal dependency

set -e

echo "🚀 Starting simple deployment of The Final Market..."

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

# Pre-deployment checks
pre_deployment_checks() {
    print_status "Running pre-deployment checks..."

    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi

    # Check if Rails can run
    if ! ruby -v &> /dev/null; then
        print_error "Ruby is not available."
        exit 1
    fi

    print_success "Pre-deployment checks completed"
}

# Build Docker image locally
build_image() {
    print_status "Building Docker image locally..."

    # Build the application image
    docker build -t thefinalmarket/the-final-market:latest .

    print_success "Docker image built successfully"
}

# Run database migrations locally
run_migrations_local() {
    print_status "Running database migrations locally..."

    # You would need to set up the database connection first
    print_warning "Database migrations require database connectivity"
    print_status "To run migrations: docker run --rm thefinalmarket/the-final-market:latest bin/rails db:migrate"

    print_success "Migration command prepared"
}

# Create production startup script
create_startup_script() {
    print_status "Creating production startup script..."

    cat > scripts/start-production.sh << 'EOF'
#!/bin/bash
# Production startup script for The Final Market

echo "🏪 Starting The Final Market in production mode..."

# Set environment variables
export RAILS_ENV=production
export RAILS_MASTER_KEY=${RAILS_MASTER_KEY}
export DATABASE_URL=${DATABASE_URL}
export REDIS_URL=${REDIS_URL}

# Start the application
echo "Starting Rails server..."
bundle exec rails server -p 3000 -b 0.0.0.0

echo "Application started on port 3000"
EOF

    chmod +x scripts/start-production.sh
    print_success "Production startup script created"
}

# Main deployment flow
main() {
    echo "🏪 The Final Market - Simple Deployment"
    echo "======================================"
    echo "Note: This is a simplified deployment without Kamal"
    echo ""

    check_environment
    pre_deployment_checks
    build_image
    run_migrations_local
    create_startup_script

    echo ""
    print_success "🎉 Simple deployment preparation completed!"
    echo ""
    echo "🌐 To start your application:"
    echo "   1. Ensure your production server is ready"
    echo "   2. Copy the Docker image to your server"
    echo "   3. Run: docker run -d -p 80:3000 --name thefinalmarket thefinalmarket/the-final-market:latest"
    echo "   4. Or use: ./scripts/start-production.sh"
    echo ""
    echo "📊 Manual deployment steps:"
    echo "   - Set up PostgreSQL and Redis on your server"
    echo "   - Configure environment variables"
    echo "   - Run database migrations"
    echo "   - Start the application server"
    echo ""
    echo "🔧 For Kamal deployment (requires Ruby >= 2.7):"
    echo "   1. Upgrade Ruby: brew install ruby@3.2"
    echo "   2. Install Kamal: gem install kamal"
    echo "   3. Use: ./scripts/deploy-no-java.sh"
}

# Handle script arguments
case "${1:-}" in
    "build")
        check_environment
        pre_deployment_checks
        build_image
        ;;
    "migrate")
        run_migrations_local
        ;;
    "start")
        create_startup_script
        ;;
    *)
        main
        ;;
esac