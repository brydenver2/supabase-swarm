# Deployment Checklist

Use this checklist to ensure your Supabase deployment is properly configured and secure.

## Pre-Deployment

### Environment Configuration
- [ ] Copy `environment-variables.txt` to `.env`
- [ ] Generate JWT_SECRET (40 characters): `openssl rand -hex 20`
- [ ] Generate POSTGRES_PASSWORD: `openssl rand -base64 32`
- [ ] Generate ANON_KEY and SERVICE_ROLE_KEY from [Supabase docs](https://supabase.com/docs/guides/self-hosting/docker#generate-api-keys)
- [ ] Set DASHBOARD_USERNAME and DASHBOARD_PASSWORD
- [ ] Configure LOGFLARE_API_KEY

### Domain & SSL (Production Only)
- [ ] Register domain name
- [ ] Point DNS A record to server IP
- [ ] Set TRAEFIK_DOMAIN in `.env`
- [ ] Set TRAEFIK_POSTGRES_DOMAIN in `.env`
- [ ] Set TRAEFIK_ACME_EMAIL in `.env`
- [ ] Generate Traefik dashboard password: `./generate-traefik-password.sh`
- [ ] Set TRAEFIK_ACME_PRODUCTION=true (after testing)

### Storage Configuration
- [ ] Create S3 bucket or use S3-compatible storage
- [ ] Generate AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY
- [ ] Set AWS_DEFAULT_REGION
- [ ] Update bucket name in docker-compose.yml if needed

### SMTP Configuration (Optional)
- [ ] Set SMTP_HOST and SMTP_PORT
- [ ] Set SMTP_USER and SMTP_PASS
- [ ] Set SMTP_ADMIN_EMAIL
- [ ] Set SMTP_SENDER_NAME

### External Database (Optional)
- [ ] Set USE_EXTERNAL_DB=true
- [ ] Set EXTERNAL_POSTGRES_HOST
- [ ] Set EXTERNAL_POSTGRES_PORT
- [ ] Set EXTERNAL_POSTGRES_DB
- [ ] Set EXTERNAL_POSTGRES_PASSWORD
- [ ] Update POSTGRES_HOST to point to external DB
- [ ] Run initialization SQL scripts on external database

## Infrastructure Setup

### Docker Environment
- [ ] Install Docker Engine (20.10+)
- [ ] Install Docker Compose v2 (for standalone)
- [ ] Initialize Docker Swarm (for production): `docker swarm init`
- [ ] Verify Docker is running: `docker info`

### Network & Firewall
- [ ] Open port 80 (HTTP)
- [ ] Open port 443 (HTTPS)
- [ ] Open port 5432 (PostgreSQL - if needed)
- [ ] Configure firewall rules
- [ ] Set up security groups (cloud providers)

### Server Requirements
- [ ] Minimum 4GB RAM (8GB recommended)
- [ ] Minimum 2 CPU cores (4 recommended)
- [ ] 50GB+ disk space
- [ ] Ubuntu 20.04+ or similar Linux distribution

## Deployment

### Run Setup Script
- [ ] Make setup.sh executable: `chmod +x setup.sh`
- [ ] Run setup for your mode:
  - Compose: `./setup.sh --compose`
  - Swarm: `./setup.sh --swarm`
  - External DB: Add `--external-db` flag

### Verify Setup
- [ ] Check Docker network created: `docker network ls | grep supabase_overlay`
- [ ] Check volumes created: `docker volume ls | grep supabase`
- [ ] (Swarm only) Check configs created: `docker config ls`

### Deploy Stack
- [ ] For Compose: `docker compose -f docker-compose.standalone.yml up -d`
- [ ] For Swarm: `docker stack deploy -c docker-compose.yml supabase`

### Verify Deployment
- [ ] Check service status:
  - Compose: `docker compose -f docker-compose.standalone.yml ps`
  - Swarm: `docker service ls`
- [ ] Check service health:
  - Compose: `docker compose -f docker-compose.standalone.yml ps`
  - Swarm: `docker service ps supabase_kong`
- [ ] Wait for all services to be healthy (may take 2-5 minutes)

## Post-Deployment

### Access Verification
- [ ] Access Supabase Studio:
  - Standalone: http://localhost:8000
  - Production: https://your-domain.com
- [ ] Login with DASHBOARD_USERNAME and DASHBOARD_PASSWORD
- [ ] Verify Studio loads correctly

### API Testing
- [ ] Test health endpoint: `curl https://your-domain.com/rest/v1/`
- [ ] Test with API key:
  ```bash
  curl https://your-domain.com/rest/v1/ \
    -H "apikey: YOUR_ANON_KEY"
  ```
- [ ] Verify authentication endpoints work
- [ ] Test realtime connections

### SSL/TLS Verification (Production)
- [ ] Verify HTTPS redirect works: `curl -I http://your-domain.com`
- [ ] Check SSL certificate: `curl -vI https://your-domain.com`
- [ ] Verify certificate is from Let's Encrypt
- [ ] Check SSL labs rating: https://www.ssllabs.com/ssltest/

### Database Verification
- [ ] Connect to database:
  - Internal: `docker exec -it supabase-db psql -U postgres`
  - External: `psql -h $EXTERNAL_POSTGRES_HOST -U postgres`
- [ ] Verify schemas exist:
  ```sql
  SELECT schema_name FROM information_schema.schemata;
  ```
- [ ] Check roles created:
  ```sql
  SELECT rolname FROM pg_roles WHERE rolname LIKE 'supabase%';
  ```

### Storage Verification
- [ ] Upload a test file through Studio
- [ ] Verify file appears in S3 bucket
- [ ] Test file download
- [ ] Test image transformation (if enabled)

### Security Headers Check
- [ ] Verify security headers are present:
  ```bash
  curl -I https://your-domain.com
  ```
- [ ] Check for:
  - Strict-Transport-Security
  - X-Frame-Options
  - X-Content-Type-Options
  - X-XSS-Protection

### Rate Limiting Test (Production)
- [ ] Test rate limiting with multiple rapid requests
- [ ] Verify rate limit is enforced
- [ ] Adjust TRAEFIK_RATE_LIMIT if needed

## Monitoring & Maintenance

### Log Configuration
- [ ] Check service logs:
  - Compose: `docker compose logs [service]`
  - Swarm: `docker service logs supabase_[service]`
- [ ] Verify log rotation is configured
- [ ] Set up centralized logging (optional)

### Backup Setup
- [ ] Configure automated database backups
- [ ] Test database restore procedure
- [ ] Back up Traefik certificates (in volume)
- [ ] Back up configuration files
- [ ] Document backup procedures

### Monitoring
- [ ] Set up health check monitoring
- [ ] Configure uptime monitoring (optional)
- [ ] Set up resource monitoring (CPU, RAM, disk)
- [ ] Configure alerts for service failures
- [ ] Monitor SSL certificate expiration

### Documentation
- [ ] Document custom configuration changes
- [ ] Save generated secrets securely
- [ ] Document backup/restore procedures
- [ ] Create runbook for common operations
- [ ] Share access credentials with team (securely)

## Security Hardening

### Immediate Actions
- [ ] Change all default passwords
- [ ] Rotate JWT secrets if using defaults
- [ ] Disable unnecessary services
- [ ] Configure IP whitelisting (if applicable)
- [ ] Review and restrict database access

### Ongoing Security
- [ ] Set up security update notifications
- [ ] Schedule regular security audits
- [ ] Monitor access logs for suspicious activity
- [ ] Keep Docker images updated
- [ ] Review and rotate credentials quarterly

### Compliance (If Required)
- [ ] Enable audit logging
- [ ] Configure data retention policies
- [ ] Document data flows
- [ ] Implement GDPR/CCPA requirements
- [ ] Set up compliance monitoring

## Troubleshooting Reference

Common issues and solutions:

### Services Won't Start
```bash
# Check logs
docker service logs supabase_kong

# Check resources
docker stats

# Verify configuration
docker compose config
```

### SSL Certificate Issues
```bash
# Check Traefik logs
docker service logs supabase_traefik

# Verify DNS
nslookup your-domain.com

# Test Let's Encrypt
curl -I http://your-domain.com/.well-known/acme-challenge/test
```

### Database Connection Issues
```bash
# Test connectivity
docker exec supabase-auth ping $POSTGRES_HOST

# Check credentials
docker exec supabase-auth env | grep POSTGRES

# Test connection
docker exec supabase-auth psql -h $POSTGRES_HOST -U postgres
```

### Performance Issues
```bash
# Check resource usage
docker stats

# Check service replicas
docker service ls

# Scale services (Swarm)
docker service scale supabase_kong=3
```

## Additional Resources

- [Quick Start Guide](QUICKSTART.md)
- [Traefik Setup](TRAEFIK_SETUP.md)
- [External Database Guide](EXTERNAL_DATABASE.md)
- [Configuration Comparison](CONFIGURATION_COMPARISON.md)
- [Supabase Documentation](https://supabase.com/docs)

## Support Checklist

When reporting issues, include:
- [ ] Deployment method (Compose/Swarm)
- [ ] Docker version: `docker version`
- [ ] Compose version: `docker compose version`
- [ ] OS and version
- [ ] Sanitized configuration (no secrets!)
- [ ] Service logs
- [ ] Steps to reproduce
- [ ] Expected vs actual behavior

---

**Note**: Keep this checklist updated as you customize your deployment.
