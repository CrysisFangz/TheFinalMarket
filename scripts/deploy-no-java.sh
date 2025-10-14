#!/bin/bash

# The Final Market - Java-Free Production Deployment Script
# This script deploys without Elasticsearch/Java dependencies

set -e

echo "🚀 Starting Java-free deployment of The Final Market..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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
        "KAMAL_REGISTRY_PASSWORD"
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

    # Check if Kamal is installed
    if ! command -v kamal &> /dev/null; then
        print_error "Kamal is not installed. Please install it first:"
        echo "  gem install kamal"
        exit 1
    fi

    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi

    print_success "Pre-deployment checks completed"
}

# Setup production secrets (Java-free)
setup_secrets() {
    print_status "Setting up production secrets (Java-free configuration)..."

    # Create .kamal/secrets if it doesn't exist
    mkdir -p .kamal/secrets

    # Create secrets file for Kamal (without Elasticsearch)
    cat > .kamal/secrets << EOF
RAILS_MASTER_KEY=${RAILS_MASTER_KEY}
DATABASE_URL=${DATABASE_URL}
REDIS_URL=${REDIS_URL}
KAMAL_REGISTRY_PASSWORD=${KAMAL_REGISTRY_PASSWORD}
DB_PASSWORD=${DB_PASSWORD}
SENTRY_DSN=${SENTRY_DSN}
LOGDNA_KEY=${LOGDNA_KEY}
SMTP_ADDRESS=${SMTP_ADDRESS}
SMTP_PORT=${SMTP_PORT}
SMTP_DOMAIN=${SMTP_DOMAIN}
SMTP_USERNAME=${SMTP_USERNAME}
SMTP_PASSWORD=${SMTP_PASSWORD}
# Elasticsearch disabled for Java-free deployment
# ELASTICSEARCH_URL=${ELASTICSEARCH_URL}
EOF

    print_success "Java-free production secrets configured"
}

# Build and deploy (Java-free configuration)
deploy_application() {
    print_status "Building and deploying application (Java-free)..."

    # Use Java-free deployment configuration
    export KAMAL_CONFIG_FILE=config/deploy.no-java.yml

    # Build the application
    print_status "Building application image..."
    kamal build

    # Deploy to production
    print_status "Deploying to production..."
    kamal deploy

    print_success "Java-free application deployed successfully"
}

# Run database migrations
run_migrations() {
    print_status "Running database migrations..."
    export KAMAL_CONFIG_FILE=config/deploy.no-java.yml
    kamal app exec "bin/rails db:migrate"
    print_success "Database migrations completed"
}

# Seed the database
seed_database() {
    print_status "Seeding database with initial data..."
    export KAMAL_CONFIG_FILE=config/deploy.no-java.yml
    kamal app exec "bin/rails db:seed"
    print_success "Database seeded successfully"
}

# Setup monitoring and logging (Java-free)
setup_monitoring() {
    print_status "Setting up monitoring and logging (Java-free)..."

    export KAMAL_CONFIG_FILE=config/deploy.no-java.yml

    # Setup log shipping if LogDNA key is provided
    if [ ! -z "${LOGDNA_KEY}" ]; then
        print_status "Configuring log shipping..."
        kamal app exec "bin/rails logdna:configure"
    fi

    # Setup error tracking if Sentry DSN is provided
    if [ ! -z "${SENTRY_DSN}" ]; then
        print_status "Configuring error tracking..."
        kamal app exec "bin/rails sentry:configure"
    fi

    print_success "Java-free monitoring and logging configured"
}

# Health check
health_check() {
    print_status "Performing health checks..."

    export KAMAL_CONFIG_FILE=config/deploy.no-java.yml

    # Wait for application to be ready
    print_status "Waiting for application to start..."
    sleep 30

    # Check if application is responding
    if curl -f -s "https://${DOMAIN_NAME}/up" > /dev/null; then
        print_success "Health check passed - application is responding"
    else
        print_warning "Health check failed - application may not be fully ready"
    fi
}

# Post-deployment cleanup
cleanup() {
    print_status "Performing post-deployment cleanup..."

    export KAMAL_CONFIG_FILE=config/deploy.no-java.yml

    # Clean up old Docker images
    kamal prune

    # Clean up old application versions
    kamal prune app

    print_success "Cleanup completed"
}

# Main deployment flow (Java-free)
main() {
    echo "🏪 The Final Market - Java-Free Production Deployment"
    echo "======================================================"
    echo "Note: This deployment runs without Elasticsearch to avoid Java dependency"
    echo ""

    check_environment
    pre_deployment_checks
    setup_secrets
    deploy_application
    run_migrations
    seed_database
    setup_monitoring
    health_check
    cleanup

    echo ""
    print_success "🎉 Java-free deployment completed successfully!"
    echo ""
    echo "🌐 Your application is now live at: https://${DOMAIN_NAME}"
    echo ""
    print_warning "Note: Search functionality uses PostgreSQL instead of Elasticsearch"
    echo "      For advanced search features, install Java and use config/deploy.production.yml"
    echo ""
    echo "📊 Monitoring and logs:"
    echo "   - Application logs: kamal logs"
    echo "   - Application console: kamal console"
    echo "   - Application status: kamal status"
    echo ""
    echo "🔧 Useful commands:"
    echo "   - Deploy updates: KAMAL_CONFIG_FILE=config/deploy.no-java.yml kamal deploy"
    echo "   - Rollback: kamal rollback"
    echo "   - SSH to server: kamal shell"
    echo "   - View logs: kamal logs"
}

# Handle script arguments
case "${1:-}" in
    "setup")
        check_environment
        setup_secrets
        ;;
    "deploy")
        check_environment
        pre_deployment_checks
        setup_secrets
        deploy_application
        ;;
    "migrate")
        export KAMAL_CONFIG_FILE=config/deploy.no-java.yml
        run_migrations
        ;;
    "seed")
        export KAMAL_CONFIG_FILE=config/deploy.no-java.yml
        seed_database
        ;;
    "health")
        export KAMAL_CONFIG_FILE=config/deploy.no-java.yml
        health_check
        ;;
    "cleanup")
        export KAMAL_CONFIG_FILE=config/deploy.no-java.yml
        cleanup
        ;;
    *)
        main
        ;;
esac