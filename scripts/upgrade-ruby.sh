#!/bin/bash

# Ruby Upgrade Script for Kamal Compatibility
# This script upgrades Ruby to version 2.7+ required for Kamal

echo "🔧 Upgrading Ruby for Kamal compatibility..."

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

# Check current Ruby version
check_ruby_version() {
    print_status "Checking current Ruby version..."

    if ! command -v ruby &> /dev/null; then
        print_error "Ruby is not installed"
        return 1
    fi

    CURRENT_VERSION=$(ruby -e "print RUBY_VERSION")
    print_status "Current Ruby version: $CURRENT_VERSION"

    # Check if version is sufficient for Kamal (>= 2.7)
    if [ "$(printf '%s\n' "2.7.0" "$CURRENT_VERSION" | sort -V | head -n1)" = "2.7.0" ]; then
        print_success "Ruby version $CURRENT_VERSION is compatible with Kamal"
        return 0
    else
        print_warning "Ruby version $CURRENT_VERSION is too old for Kamal (requires >= 2.7)"
        return 1
    fi
}

# Install Ruby with Homebrew (macOS)
install_ruby_brew() {
    print_status "Installing Ruby 3.4.1 with Homebrew..."

    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        print_error "Homebrew is not installed"
        print_status "Please install Homebrew first:"
        print_status "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi

    # Install Ruby 3.4.1
    brew install ruby@3.4

    # Add to PATH
    echo 'export PATH="/opt/homebrew/opt/ruby@3.4/bin:$PATH"' >> ~/.zshrc
    echo 'export PATH="/opt/homebrew/opt/ruby@3.4/bin:$PATH"' >> ~/.bashrc

    print_success "Ruby 3.4.1 installed"
}

# Install Ruby with rbenv (Alternative)
install_ruby_rbenv() {
    print_status "Installing Ruby 3.4.1 with rbenv..."

    # Install rbenv if not present
    if ! command -v rbenv &> /dev/null; then
        print_status "Installing rbenv..."
        brew install rbenv

        # Configure rbenv
        echo 'eval "$(rbenv init -)"' >> ~/.zshrc
        echo 'eval "$(rbenv init -)"' >> ~/.bashrc
    fi

    # Install Ruby 3.4.1
    rbenv install 3.4.1
    rbenv global 3.4.1

    print_success "Ruby 3.4.1 installed with rbenv"
}

# Install Kamal after Ruby upgrade
install_kamal() {
    print_status "Installing Kamal..."

    # Set Ruby path if using Homebrew
    if [ -d "/opt/homebrew/opt/ruby@3.4" ]; then
        export PATH="/opt/homebrew/opt/ruby@3.4/bin:$PATH"
    fi

    # Install Kamal
    gem install kamal

    print_success "Kamal installed successfully"
}

# Verify installation
verify_installation() {
    print_status "Verifying installation..."

    # Check Kamal version
    if command -v kamal &> /dev/null; then
        KAMAL_VERSION=$(kamal --version)
        print_success "Kamal installed: $KAMAL_VERSION"
    else
        print_error "Kamal installation failed"
        return 1
    fi

    # Check Ruby version
    RUBY_VERSION=$(ruby -e "print RUBY_VERSION")
    print_success "Ruby version: $RUBY_VERSION"

    print_success "Installation verified"
}

# Main upgrade flow
main() {
    echo "💎 Ruby Upgrade for Kamal Deployment"
    echo "===================================="

    # Check current version
    if check_ruby_version; then
        print_success "Ruby version is already compatible with Kamal"
        install_kamal
    else
        print_status "Upgrading Ruby for Kamal compatibility..."

        # Try Homebrew first
        if command -v brew &> /dev/null; then
            install_ruby_brew
        else
            # Try rbenv
            install_ruby_rbenv
        fi

        # Install Kamal
        install_kamal
    fi

    # Verify everything works
    verify_installation

    echo ""
    print_success "✅ Ruby upgrade completed!"
    echo ""
    echo "🚀 Next steps:"
    echo "1. Restart your terminal: source ~/.zshrc"
    echo "2. Verify Kamal: kamal --version"
    echo "3. Run deployment: ./scripts/deploy-no-java.sh"
    echo ""
    echo "🎯 Kamal deployment options:"
    echo "   - Java-free: ./scripts/deploy-no-java.sh"
    echo "   - Full deployment: ./scripts/deploy.sh"
}

# Handle script arguments
case "${1:-}" in
    "check")
        check_ruby_version
        ;;
    "brew")
        install_ruby_brew
        install_kamal
        ;;
    "rbenv")
        install_ruby_rbenv
        install_kamal
        ;;
    "kamal")
        install_kamal
        ;;
    "verify")
        verify_installation
        ;;
    *)
        main
        ;;
esac