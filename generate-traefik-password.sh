#!/bin/bash

# =============================================================================
# Generate Traefik Dashboard Password
# =============================================================================
# This script generates a bcrypt-hashed password for the Traefik dashboard
# in the format required by the basicauth middleware.
#
# Usage: ./generate-traefik-password.sh [username] [password]
# =============================================================================

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

USERNAME="${1:-admin}"
PASSWORD="${2}"

if [ -z "$PASSWORD" ]; then
    echo -e "${YELLOW}No password provided. Generating a random one...${NC}"
    PASSWORD=$(openssl rand -base64 16)
    echo -e "${BLUE}Generated password: ${GREEN}${PASSWORD}${NC}"
fi

echo ""
echo -e "${BLUE}Generating htpasswd for Traefik...${NC}"

# Check if htpasswd is available
if command -v htpasswd &> /dev/null; then
    # Use htpasswd if available
    HASHED=$(htpasswd -nbB "$USERNAME" "$PASSWORD" 2>/dev/null | sed 's/\$/\$\$/g')
elif command -v openssl &> /dev/null; then
    # Fallback to a simple method using openssl
    echo -e "${YELLOW}Warning: htpasswd not found, using basic method${NC}"
    HASHED="${USERNAME}:$(openssl passwd -apr1 "$PASSWORD")"
else
    echo -e "${RED}Error: Neither htpasswd nor openssl found${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Add this to your .env file:${NC}"
echo "TRAEFIK_DASHBOARD_USER=${USERNAME}"
echo "TRAEFIK_DASHBOARD_PASSWORD=${HASHED}"
echo ""
echo -e "${BLUE}Or use this directly in docker-compose labels:${NC}"
echo "traefik.http.middlewares.dashboard-auth.basicauth.users=${HASHED}"
echo ""
