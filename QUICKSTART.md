# Quick Start Guide

This guide will help you get Supabase running quickly with the new Traefik v3 load balancer and optional external database support.

## Prerequisites

- Docker Engine 20.10+
- Docker Compose v2.0+ (or Docker Swarm for production)
- Domain name with DNS pointing to your server (for SSL)
- (Optional) External PostgreSQL 15.x+ database

## Quick Start: Development Setup

For a quick development setup without SSL:

```bash
# 1. Clone the repository
git clone <your-repo-url>
cd supabase-swarm

# 2. Create environment file
cp environment-variables.txt .env

# 3. Generate secrets
# JWT Secret (40 characters for Supabase)
openssl rand -hex 20

# Database password
openssl rand -base64 32

# 4. Edit .env and set at minimum:
# - POSTGRES_PASSWORD
# - JWT_SECRET
# - ANON_KEY (generate at https://supabase.com/docs/guides/self-hosting/docker#generate-api-keys)
# - SERVICE_ROLE_KEY

# 5. Run setup
./setup.sh --compose

# 6. Start services
docker compose -f docker-compose.standalone.yml up -d

# 7. Access Supabase
# Studio: http://localhost:8000
```

## Production Setup: Docker Swarm with Traefik

For production with automatic SSL and load balancing:

```bash
# 1. Initialize Docker Swarm (if not already done)
docker swarm init

# 2. Clone and configure
git clone <your-repo-url>
cd supabase-swarm
cp environment-variables.txt .env

# 3. Configure your domain and SSL
nano .env
# Set these variables:
# TRAEFIK_DOMAIN=your-domain.com
# TRAEFIK_POSTGRES_DOMAIN=postgres.your-domain.com
# TRAEFIK_ACME_EMAIL=admin@your-domain.com
# TRAEFIK_ACME_PRODUCTION=true

# 4. Generate Traefik dashboard password
./generate-traefik-password.sh admin
# Copy the output to your .env file

# 5. Generate other required secrets (same as development)
openssl rand -hex 20  # JWT_SECRET
openssl rand -base64 32  # POSTGRES_PASSWORD
# Generate ANON_KEY and SERVICE_ROLE_KEY from Supabase docs

# 6. Run setup for Swarm
./setup.sh --swarm

# 7. Deploy the stack
docker stack deploy -c docker-compose.yml supabase

# 8. Check deployment status
docker service ls

# 9. Access services
# Supabase: https://your-domain.com
# Traefik Dashboard: https://traefik.your-domain.com
```

## Production Setup: External Database

To use a managed database service (AWS RDS, Google Cloud SQL, etc.):

```bash
# 1. Complete steps 1-4 from Production Setup above

# 2. Configure external database in .env
nano .env
# Set:
# USE_EXTERNAL_DB=true
# EXTERNAL_POSTGRES_HOST=your-db-host.com
# EXTERNAL_POSTGRES_PORT=5432
# EXTERNAL_POSTGRES_DB=postgres
# EXTERNAL_POSTGRES_PASSWORD=your-db-password
# POSTGRES_HOST=your-db-host.com  # Point to external DB

# 3. Initialize external database
# Connect to your database and run:
psql -h your-db-host.com -U postgres -d postgres

# Then run initialization scripts:
for script in volumes/db/{roles,jwt,webhooks,_supabase,pooler,realtime,logs}.sql; do
  psql -h your-db-host.com -U postgres -d postgres -f $script
done

# 4. Run setup with external DB flag
./setup.sh --swarm --external-db

# 5. Deploy (internal db service will be skipped)
docker stack deploy -c docker-compose.yml supabase
```

## Production Setup: Using External Traefik

If you already have Traefik running in your Docker Swarm cluster:

```bash
# 1. Configure in .env
nano .env
# Set:
# DEPLOY_TRAEFIK=false
# TRAEFIK_DOMAIN=your-domain.com  # Still needed for routing
# TRAEFIK_RATE_LIMIT=100  # Still needed for middleware

# 2. Comment out or remove the traefik service from docker-compose.yml
# Keep all labels on the Kong service - they're needed for your external Traefik

# 3. Run setup
./setup.sh --swarm

# 4. Deploy
docker stack deploy -c docker-compose.yml supabase

# Your external Traefik will automatically discover and route traffic to Supabase
```

📖 **See [EXTERNAL_TRAEFIK.md](EXTERNAL_TRAEFIK.md) for detailed instructions**
docker stack deploy -c docker-compose.yml supabase
```

## Configuration Checklist

### Essential Variables (All Setups)
- [ ] `POSTGRES_PASSWORD` - Strong password for database
- [ ] `JWT_SECRET` - 40-character secret for JWT
- [ ] `ANON_KEY` - Anonymous access key
- [ ] `SERVICE_ROLE_KEY` - Service role key
- [ ] `DASHBOARD_USERNAME` - Kong dashboard username
- [ ] `DASHBOARD_PASSWORD` - Kong dashboard password

### Traefik Variables (Production)
- [ ] `TRAEFIK_DOMAIN` - Your domain name
- [ ] `TRAEFIK_POSTGRES_DOMAIN` - PostgreSQL subdomain
- [ ] `TRAEFIK_ACME_EMAIL` - Email for Let's Encrypt
- [ ] `TRAEFIK_ACME_PRODUCTION` - Set to true for production
- [ ] `TRAEFIK_DASHBOARD_USER` - Traefik dashboard username
- [ ] `TRAEFIK_DASHBOARD_PASSWORD` - Hashed password (use script)

### External Database Variables (Optional)
- [ ] `USE_EXTERNAL_DB=true` - Enable external DB mode
- [ ] `EXTERNAL_POSTGRES_HOST` - External DB hostname
- [ ] `EXTERNAL_POSTGRES_PORT` - External DB port
- [ ] `EXTERNAL_POSTGRES_DB` - Database name
- [ ] `EXTERNAL_POSTGRES_PASSWORD` - External DB password
- [ ] `POSTGRES_HOST` - Set to external DB host

### Storage Variables (Production)
- [ ] `AWS_ACCESS_KEY_ID` - S3 access key
- [ ] `AWS_SECRET_ACCESS_KEY` - S3 secret key
- [ ] `AWS_DEFAULT_REGION` - AWS region

### SMTP Variables (Optional)
- [ ] `SMTP_HOST` - SMTP server
- [ ] `SMTP_PORT` - SMTP port
- [ ] `SMTP_USER` - SMTP username
- [ ] `SMTP_PASS` - SMTP password
- [ ] `SMTP_ADMIN_EMAIL` - From email address

## Testing Your Setup

### Check Service Health
```bash
# For Docker Swarm
docker service ls
docker service ps supabase_kong

# For Docker Compose
docker compose -f docker-compose.standalone.yml ps
```

### Test Database Connection
```bash
# Internal database
docker exec -it supabase-db psql -U postgres

# External database
psql -h your-external-host -U postgres
```

### Test API Endpoints
```bash
# Health check
curl https://your-domain.com/rest/v1/

# With API key
curl https://your-domain.com/rest/v1/ \
  -H "apikey: YOUR_ANON_KEY"
```

### Check SSL Certificate
```bash
curl -vI https://your-domain.com 2>&1 | grep -i "subject:\|issuer:"
```

## Troubleshooting

### Services Won't Start
```bash
# Check logs
docker service logs supabase_kong
docker logs supabase-kong  # for compose

# Verify configuration
docker compose -f docker-compose.yml config
```

### SSL Certificate Issues
```bash
# Check Traefik logs
docker service logs supabase_traefik

# Verify DNS
dig your-domain.com
nslookup your-domain.com

# Check ports
netstat -tulpn | grep -E ':(80|443)'
```

### Database Connection Issues
```bash
# Test network connectivity
docker exec -it supabase-auth ping $POSTGRES_HOST

# Check database logs
docker service logs supabase_db

# Verify credentials
docker exec -it supabase-auth env | grep POSTGRES
```

### Traefik Dashboard Not Accessible
```bash
# Verify password format
echo "TRAEFIK_DASHBOARD_PASSWORD" | base64 -d

# Check Traefik configuration
docker exec -it $(docker ps -qf name=traefik) cat /etc/traefik/traefik.yml

# Regenerate password
./generate-traefik-password.sh admin
```

## Next Steps

1. **Secure Your Installation**
   - Change all default passwords
   - Configure firewall rules
   - Set up monitoring and logging
   - Enable backups

2. **Configure Email**
   - Set up SMTP settings
   - Test email delivery
   - Customize email templates

3. **Set Up Storage**
   - Configure S3-compatible storage
   - Test file uploads
   - Set up CDN (optional)

4. **Monitor Your System**
   - Set up health checks
   - Configure alerts
   - Monitor resource usage
   - Review access logs

## Additional Resources

- [Traefik Setup Guide](TRAEFIK_SETUP.md)
- [External Database Guide](EXTERNAL_DATABASE.md)
- [Supabase Documentation](https://supabase.com/docs)
- [Traefik Documentation](https://doc.traefik.io/traefik/)

## Getting Help

If you encounter issues:

1. Check the troubleshooting section above
2. Review service logs
3. Consult the documentation
4. Open an issue on GitHub with:
   - Your configuration (sanitized)
   - Error messages
   - Steps to reproduce
