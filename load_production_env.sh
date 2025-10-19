#!/bin/bash

# Production Environment Loader for The Final Market
# This script loads environment variables from .env.production for production deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔧 Loading Production Environment Variables...${NC}"

# Check if .env.production exists
if [ ! -f ".env.production" ]; then
    echo -e "${RED}❌ Error: .env.production file not found!${NC}"
    exit 1
fi

# Load environment variables from .env.production
if [ -f ".env.production" ]; then
    echo -e "${YELLOW}📋 Loading variables from .env.production...${NC}"
    source .env.production

    # Verify critical variables are loaded
    if [ -z "$DATABASE_URL" ]; then
        echo -e "${RED}❌ Error: DATABASE_URL not found in .env.production${NC}"
        exit 1
    fi

    if [ -z "$SECRET_KEY_BASE" ]; then
        echo -e "${RED}❌ Error: SECRET_KEY_BASE not found in .env.production${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ Critical environment variables loaded:${NC}"
    echo -e "   DATABASE_URL: ${DATABASE_URL:0:50}..."
    echo -e "   SECRET_KEY_BASE: ${SECRET_KEY_BASE:0:20}..."
    echo -e "   RAILS_ENV: $RAILS_ENV"
    echo -e "   DOMAIN_NAME: $DOMAIN_NAME"
fi

echo -e "${GREEN}🎉 Production environment loaded successfully!${NC}"
echo -e "${YELLOW}💡 You can now run Rails commands with: bundle exec rails server${NC}"