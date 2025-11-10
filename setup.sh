#!/bin/bash

# =============================================================================
# SUPABASE DOCKER SETUP SCRIPT
# =============================================================================
# This script initializes external resources needed for Supabase Docker deployments.
# For Docker Compose: Uses existing docker-compose.standalone.yml
# For Docker Swarm: Creates external volumes, networks, and configs
#
# Usage: ./setup.sh [--swarm|--compose] [--external-db]
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default mode
MODE="compose"
USE_EXTERNAL_DB="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --swarm)
      MODE="swarm"
      shift
      ;;
    --compose)
      MODE="compose"
      shift
      ;;
    --external-db)
      USE_EXTERNAL_DB="true"
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--swarm|--compose] [--external-db]"
      echo "  --swarm        Setup for Docker Swarm deployment (creates external resources)"
      echo "  --compose      Setup for Docker Compose deployment (uses standalone file)"
      echo "  --external-db  Configure for external database (skips internal DB setup)"
      exit 0
      ;;
    *)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}🚀 Supabase Docker Setup Script${NC}"
echo -e "${BLUE}Mode: ${MODE}${NC}"
echo -e "${BLUE}External DB: ${USE_EXTERNAL_DB}${NC}"
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

print_status "Docker is running"

# Check if .env file exists
if [ ! -f ".env" ]; then
    print_warning ".env file not found. Creating from template..."
    if [ -f "environment-variables.txt" ]; then
        cp environment-variables.txt .env
        print_status "Created .env from environment-variables.txt"
        print_warning "Please edit .env file with your actual values before running docker-compose"
    else
        print_error "environment-variables.txt template not found"
        exit 1
    fi
else
    print_status ".env file found"
fi

# Create external network
echo ""
echo -e "${BLUE}Creating external network...${NC}"
if docker network ls | grep -q "supabase_overlay"; then
    print_warning "Network 'supabase_overlay' already exists"
else
    if [ "$MODE" = "swarm" ]; then
        # Create overlay network for Docker Swarm
        docker network create --driver overlay supabase_overlay
        print_status "Created overlay network 'supabase_overlay'"
    else
        # Create bridge network for Docker Compose
        docker network create supabase_overlay
        print_status "Created bridge network 'supabase_overlay'"
    fi
fi

# Create external volumes
echo ""
echo -e "${BLUE}Creating external volumes...${NC}"

if [ "$USE_EXTERNAL_DB" = "true" ]; then
    print_warning "Using external database - skipping database volumes"
    volumes=(
        "supabase-production-storage-data"
        "supabase-production-functions-data"
        "traefik-certificates"
    )
else
    volumes=(
        "supabase-production-storage-data"
        "supabase-production-functions-data"
        "supabase-production-db-data"
        "supabase-production-db-config"
        "traefik-certificates"
    )
fi

for volume in "${volumes[@]}"; do
    if docker volume ls | grep -q "$volume"; then
        print_warning "Volume '$volume' already exists"
    else
        docker volume create "$volume"
        print_status "Created volume '$volume'"
    fi
done

# Create external configs (Docker Swarm only)
if [ "$MODE" = "swarm" ]; then
    echo ""
    echo -e "${BLUE}Creating external configs for Docker Swarm...${NC}"
    
    # Check if we're in a swarm
    if ! docker info | grep -q "Swarm: active"; then
        print_error "Docker Swarm is not active. Please initialize swarm first:"
        echo "  docker swarm init"
        exit 1
    fi
    
    # Create configs from files in volumes directory
    configs=(
        "99-logs.sql:volumes/db/logs.sql"
        "99-realtime.sql:volumes/db/realtime.sql"
        "99-roles.sql:volumes/db/roles.sql"
        "98-webhooks.sql:volumes/db/webhooks.sql"
        "99-jwt.sql:volumes/db/jwt.sql"
        "97-_supabase.sql:volumes/db/_supabase.sql"
        "99-pooler.sql:volumes/db/pooler.sql"
        "vector.yml:volumes/logs/vector.yml"
        "kong.yml:volumes/api/kong.yml"
        "main.ts:volumes/functions/main/index.ts"
        "traefik.yml:volumes/traefik/traefik.yml"
    )
    
    for config in "${configs[@]}"; do
        IFS=':' read -r config_name file_path <<< "$config"
        
        if docker config ls | grep -q "$config_name"; then
            print_warning "Config '$config_name' already exists"
        else
            if [ -f "$file_path" ]; then
                docker config create "$config_name" "$file_path"
                print_status "Created config '$config_name'"
            else
                print_error "File '$file_path' not found for config '$config_name'"
            fi
        fi
    done
fi

# Check for standalone compose file for Docker Compose users
if [ "$MODE" = "compose" ]; then
    echo ""
    echo -e "${BLUE}Checking Docker Compose configuration...${NC}"
    
    if [ -f "docker-compose.standalone.yml" ]; then
        print_status "Found docker-compose.standalone.yml - ready for Docker Compose deployment"
        echo ""
        echo -e "${YELLOW}💡 For Docker Compose deployment, use:${NC}"
        echo "   docker-compose -f docker-compose.standalone.yml up -d"
    else
        print_error "docker-compose.standalone.yml not found!"
        echo "This file should be included in the repository."
        exit 1
    fi
fi

# Generate secrets if they don't exist
echo ""
echo -e "${BLUE}Checking for required secrets...${NC}"

# Check if JWT_SECRET is set in .env
if grep -q "JWT_SECRET=your-super-secret-jwt-token-exactly-40-characters-long" .env; then
    print_warning "JWT_SECRET needs to be generated"
    echo "Run: openssl rand -hex 20"
fi

# Check if POSTGRES_PASSWORD is set
if grep -q "POSTGRES_PASSWORD=your-super-secret-and-long-postgres-password" .env; then
    print_warning "POSTGRES_PASSWORD needs to be generated"
    echo "Run: openssl rand -base64 32"
fi

# Check if API keys are set
if grep -q "ANON_KEY=your-anon-key-here" .env; then
    print_warning "ANON_KEY needs to be generated"
    echo "Visit: https://supabase.com/docs/guides/self-hosting/docker#generate-api-keys"
fi

if grep -q "SERVICE_ROLE_KEY=your-service-role-key-here" .env; then
    print_warning "SERVICE_ROLE_KEY needs to be generated"
    echo "Visit: https://supabase.com/docs/guides/self-hosting/docker#generate-api-keys"
fi

# Check if S3 credentials are set (critical for production)
if grep -q "AWS_ACCESS_KEY_ID=your-aws-access-key" .env; then
    print_warning "AWS_ACCESS_KEY_ID needs to be configured"
    echo "This Docker Swarm setup uses S3-compatible storage by default"
    echo "File uploads will fail without proper S3 configuration"
fi

if grep -q "AWS_SECRET_ACCESS_KEY=your-aws-secret-key" .env; then
    print_warning "AWS_SECRET_ACCESS_KEY needs to be configured"
    echo "Get credentials from AWS IAM Console or your S3-compatible provider"
fi

# Check external database configuration if enabled
echo ""
if [ "$USE_EXTERNAL_DB" = "true" ] || grep -q "USE_EXTERNAL_DB=true" .env 2>/dev/null; then
    echo -e "${BLUE}Checking external database configuration...${NC}"
    
    if grep -q "EXTERNAL_POSTGRES_HOST=your-external-db-host.com" .env; then
        print_warning "EXTERNAL_POSTGRES_HOST needs to be configured"
        echo "Set this to your external database hostname or IP address"
    fi
    
    if grep -q "EXTERNAL_POSTGRES_PASSWORD=your-external-db-password" .env; then
        print_warning "EXTERNAL_POSTGRES_PASSWORD needs to be configured"
        echo "Set this to your external database password"
    fi
    
    print_warning "When using external database:"
    echo "  - Ensure the database is accessible from your Docker network"
    echo "  - Run the initialization SQL scripts from volumes/db/ on your external database"
    echo "  - Set POSTGRES_HOST to your external database host in .env"
    echo "  - The internal 'db' service will not be deployed"
fi

# Check Traefik configuration
echo ""
echo -e "${BLUE}Checking Traefik load balancer configuration...${NC}"

if grep -q "TRAEFIK_DOMAIN=your-domain.com" .env; then
    print_warning "TRAEFIK_DOMAIN needs to be configured"
    echo "Set this to your domain name for SSL certificate generation"
fi

if grep -q "TRAEFIK_ACME_EMAIL=admin@your-domain.com" .env; then
    print_warning "TRAEFIK_ACME_EMAIL needs to be configured"
    echo "Set this to your email for Let's Encrypt certificate notifications"
fi

if grep -q "TRAEFIK_DASHBOARD_PASSWORD=change-this-secure-password" .env; then
    print_warning "TRAEFIK_DASHBOARD_PASSWORD needs to be changed"
    echo "Generate a secure password for the Traefik dashboard"
fi

echo ""
echo -e "${GREEN}🎉 Setup completed successfully!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Edit .env file with your actual values"
echo "2. Generate required secrets (see warnings above)"
echo "3. Deploy with:"
if [ "$MODE" = "swarm" ]; then
    echo "   ./deploy-swarm.sh"
    echo "   (or manually: docker stack deploy -c docker-compose.yml supabase)"
else
    echo "   docker-compose -f docker-compose.standalone.yml up -d"
fi
echo ""
echo -e "${BLUE}Access Supabase Studio at:${NC}"
echo "   http://localhost:8000"
echo ""
echo -e "${BLUE}Default Studio credentials:${NC}"
echo "   Username: supabase"
echo "   Password: this_password_is_insecure_and_should_be_updated"
echo ""
echo -e "${YELLOW}⚠️  Remember to change default passwords in production!${NC}"
