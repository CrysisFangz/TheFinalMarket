#!/bin/bash

# Fix Ruby Gem Permissions Script
# This script resolves gem installation permission issues

echo "🔧 Fixing Ruby Gem Permissions..."

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

# Fix gem permissions
fix_gem_permissions() {
    print_status "Fixing Ruby gem permissions..."

    # Create local gem directory if it doesn't exist
    mkdir -p ~/.gem

    # Install Kamal to user directory
    print_status "Installing Kamal to user directory..."
    gem install kamal --user-install

    # Add gem bin directory to PATH if not already there
    if ! echo $PATH | grep -q "$HOME/.gem/ruby"; then
        print_status "Adding gem bin directory to PATH..."
        echo 'export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH"' >> ~/.zshrc
        echo 'export PATH="$HOME/.gem/ruby/2.6.0/bin:$PATH"' >> ~/.bashrc
        print_success "Added gem bin directory to PATH"
    fi

    print_success "Gem permissions fixed and Kamal installed"
}

# Alternative: Use rbenv or rvm
install_with_rbenv() {
    print_status "Installing Ruby with rbenv (alternative method)..."

    # Install rbenv if not present
    if ! command -v rbenv &> /dev/null; then
        print_status "Installing rbenv..."
        brew install rbenv
        echo 'eval "$(rbenv init -)"' >> ~/.zshrc
        echo 'eval "$(rbenv init -)"' >> ~/.bashrc
    fi

    # Install Ruby
    print_status "Installing Ruby 3.4.1..."
    rbenv install 3.4.1
    rbenv global 3.4.1

    # Install Kamal
    print_status "Installing Kamal..."
    gem install kamal

    print_success "Ruby and Kamal installed with rbenv"
}

# Main execution
main() {
    echo "💎 Ruby Gem Permissions Fixer"
    echo "=============================="

    # Try to fix permissions first
    if command -v gem &> /dev/null; then
        fix_gem_permissions
    else
        print_error "Ruby is not installed. Please install Ruby first:"
        echo "  brew install ruby"
        exit 1
    fi

    echo ""
    print_success "✅ Gem permissions fixed!"
    echo ""
    echo "🔧 Next steps:"
    echo "1. Restart your terminal or run: source ~/.zshrc"
    echo "2. Verify Kamal installation: kamal --version"
    echo "3. Run deployment: ./scripts/deploy-no-java.sh"
    echo ""
    echo "Or if you prefer rbenv:"
    echo "1. Run: ./scripts/fix-gem-permissions.sh rbenv"
    echo "2. Then proceed with deployment"
}

# Handle script arguments
case "${1:-}" in
    "rbenv")
        install_with_rbenv
        ;;
    *)
        main
        ;;
esac