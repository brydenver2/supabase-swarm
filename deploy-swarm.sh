#!/bin/bash

# =============================================================================
# SUPABASE DOCKER SWARM DEPLOYMENT SCRIPT
# =============================================================================
# This script loads environment variables from .env file and deploys to Docker Swarm
# Docker Swarm doesn't support env_file directive, so we need to export variables
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

echo -e "${BLUE}🚀 Supabase Docker Swarm Deployment${NC}"
echo ""

# Check if .env file exists
if [ ! -f ".env" ]; then
    print_error ".env file not found!"
    echo "Please create a .env file from environment-variables.txt template"
    exit 1
fi

print_status "Found .env file"

# Load environment variables from .env file
echo -e "${BLUE}Loading environment variables...${NC}"
set -a  # automatically export all variables
if ! source .env 2>/dev/null; then
    print_error "Failed to load .env file!"
    echo "Common issues:"
    echo "  - Values with spaces must be quoted: VAR=\"value with spaces\""
    echo "  - No spaces around = sign: VAR=value (not VAR = value)"
    echo "  - No special characters without quotes"
    echo ""
    echo "Please check your .env file and try again."
    exit 1
fi
set +a  # stop automatically exporting

print_status "Environment variables loaded"

# Check if Docker Swarm is active
if ! docker info | grep -q "Swarm: active"; then
    print_error "Docker Swarm is not active!"
    echo "Please initialize swarm first: docker swarm init"
    exit 1
fi

print_status "Docker Swarm is active"

# Check if required environment variables are set
required_vars=(
    "POSTGRES_PASSWORD"
    "JWT_SECRET"
    "ANON_KEY"
    "SERVICE_ROLE_KEY"
)

# Optional but recommended for production
production_vars=(
    "TRAEFIK_DOMAIN"
    "TRAEFIK_ACME_EMAIL"
    "AWS_ACCESS_KEY_ID"
    "AWS_SECRET_ACCESS_KEY"
    "AWS_DEFAULT_REGION"
)

missing_vars=()
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -ne 0 ]; then
    print_error "Missing required environment variables:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    echo ""
    echo "Please set these variables in your .env file"
    exit 1
fi

print_status "Required environment variables are set"

# Check for production variables and warn if missing
missing_production=()
for var in "${production_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_production+=("$var")
    fi
done

if [ ${#missing_production[@]} -ne 0 ]; then
    print_warning "Missing recommended production environment variables:"
    for var in "${missing_production[@]}"; do
        echo "  - $var"
    done
    echo ""
    echo "⚠️  These are not required but highly recommended for production:"
    echo "   - TRAEFIK_DOMAIN and TRAEFIK_ACME_EMAIL: For automatic SSL/TLS"
    echo "   - AWS credentials: For S3-compatible file storage"
    echo ""
fi

# Check if using external database
if [ "${USE_EXTERNAL_DB}" = "true" ]; then
    print_status "Using external database configuration"
    if [ -z "${EXTERNAL_POSTGRES_HOST}" ] || [ -z "${EXTERNAL_POSTGRES_PASSWORD}" ]; then
        print_error "External database enabled but EXTERNAL_POSTGRES_HOST or EXTERNAL_POSTGRES_PASSWORD not set!"
        exit 1
    fi
else
    print_status "Using internal database"
fi

# Deploy the stack
echo -e "${BLUE}Deploying Supabase stack...${NC}"
docker stack deploy -c docker-compose.yml supabase

print_status "Stack deployment initiated"

echo ""
echo -e "${GREEN}🎉 Deployment completed!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Check service status: docker stack services supabase"
echo "2. Check service health: docker stack ps supabase"
echo "3. View logs: docker service logs supabase_traefik"
echo "4. View logs: docker service logs supabase_kong"
echo ""
echo -e "${BLUE}Access your Supabase instance:${NC}"
if [ -n "${TRAEFIK_DOMAIN}" ]; then
    echo "   Supabase Studio: https://${TRAEFIK_DOMAIN}"
    echo "   Traefik Dashboard: https://traefik.${TRAEFIK_DOMAIN}"
    echo "   Note: Wait for SSL certificates to be issued (may take 1-2 minutes)"
else
    echo "   Supabase Studio: http://localhost:8000"
    echo "   Note: Configure TRAEFIK_DOMAIN for automatic SSL"
fi
echo ""
echo -e "${BLUE}Default Kong Dashboard credentials:${NC}"
echo "   Username: ${DASHBOARD_USERNAME:-supabase}"
echo "   Password: (check your .env file)"
echo ""
echo -e "${YELLOW}⚠️  Security Reminders:${NC}"
echo "   - Change default passwords immediately"
echo "   - Review security settings in .env"
echo "   - Set up monitoring and backups"
echo "   - Check DEPLOYMENT_CHECKLIST.md for complete security review"
echo ""
