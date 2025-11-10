# Configuration Comparison: docker-compose.yml vs docker-compose.standalone.yml

This document explains the differences between the two Docker Compose files and when to use each.

## docker-compose.yml (Production - Docker Swarm)

**Purpose**: Production deployments with Docker Swarm and Traefik load balancer

**Features**:
- ✅ Traefik v3 load balancer with automatic SSL
- ✅ Let's Encrypt integration for TLS certificates
- ✅ Security middlewares (rate limiting, security headers)
- ✅ High availability support with Docker Swarm
- ✅ External database support
- ✅ Scaling capabilities
- ✅ Zero-downtime deployments
- ✅ External volumes and configs

**Deployment Method**:
```bash
# Initialize swarm
docker swarm init

# Setup
./setup.sh --swarm

# Deploy
docker stack deploy -c docker-compose.yml supabase
```

**Best For**:
- Production environments
- Multi-server setups
- Public-facing applications
- High-availability requirements
- Automatic SSL certificate management

## docker-compose.standalone.yml (Development - Docker Compose)

**Purpose**: Local development and single-server testing

**Features**:
- ✅ Simpler configuration
- ✅ Local volume mounts
- ✅ No external resources required
- ✅ Faster startup
- ✅ Easier debugging
- ❌ No automatic SSL
- ❌ No load balancer
- ❌ No high availability

**Deployment Method**:
```bash
# Setup
./setup.sh --compose

# Start
docker compose -f docker-compose.standalone.yml up -d
```

**Best For**:
- Local development
- Testing and evaluation
- Single-server deployments
- Development environments
- Internal/private networks

## Key Differences

### Network Configuration

| Feature | docker-compose.yml | docker-compose.standalone.yml |
|---------|-------------------|------------------------------|
| Network Type | Overlay (Swarm) | Bridge (Compose) |
| External Network | Required | Created automatically |
| Multi-host | Yes | No |

### Volume Management

| Feature | docker-compose.yml | docker-compose.standalone.yml |
|---------|-------------------|------------------------------|
| Volume Type | External volumes | Local volumes or mounts |
| Pre-creation | Required via setup.sh | Automatic |
| Sharing | Across swarm nodes | Single host only |

### Service Configuration

| Feature | docker-compose.yml | docker-compose.standalone.yml |
|---------|-------------------|------------------------------|
| Traefik | Included | Not included |
| SSL/TLS | Automatic (Let's Encrypt) | Manual or none |
| Restart Policy | Deploy policies | Simple restart |
| Scaling | Yes (replicas) | Limited |
| Configs | External configs | Volume mounts |

### Load Balancing

| Feature | docker-compose.yml | docker-compose.standalone.yml |
|---------|-------------------|------------------------------|
| Load Balancer | Traefik v3 | None (direct access) |
| SSL Termination | Traefik | None |
| Routing | Traefik labels | Docker networking |
| Health Checks | Traefik + Docker | Docker only |

### Security Features

| Feature | docker-compose.yml | docker-compose.standalone.yml |
|---------|-------------------|------------------------------|
| Automatic HTTPS | Yes | No |
| Rate Limiting | Yes (Traefik) | No |
| Security Headers | Yes (Traefik) | No |
| IP Whitelisting | Yes (Traefik) | No |

## Migration Path

### From Standalone to Production

1. **Backup Your Data**:
   ```bash
   docker exec supabase-db pg_dump -U postgres > backup.sql
   ```

2. **Export Storage Files**:
   ```bash
   docker cp supabase-storage:/var/lib/storage ./storage-backup
   ```

3. **Stop Standalone**:
   ```bash
   docker compose -f docker-compose.standalone.yml down
   ```

4. **Initialize Swarm**:
   ```bash
   docker swarm init
   ```

5. **Configure Production Settings**:
   - Update `.env` with production values
   - Set `TRAEFIK_DOMAIN`
   - Configure SSL email
   - Set secure passwords

6. **Run Setup**:
   ```bash
   ./setup.sh --swarm
   ```

7. **Restore Data** (if needed):
   ```bash
   # After deployment
   docker exec -i supabase-db psql -U postgres < backup.sql
   ```

8. **Deploy Production Stack**:
   ```bash
   docker stack deploy -c docker-compose.yml supabase
   ```

## Environment Variable Differences

### Both Files Use:
- All Supabase core variables
- Database configuration
- JWT secrets
- API keys
- SMTP settings
- Storage configuration

### Production Only (docker-compose.yml):
```bash
# Traefik Configuration
TRAEFIK_DOMAIN=your-domain.com
TRAEFIK_POSTGRES_DOMAIN=postgres.your-domain.com
TRAEFIK_ACME_EMAIL=admin@your-domain.com
TRAEFIK_ACME_PRODUCTION=true
TRAEFIK_RATE_LIMIT=100
TRAEFIK_WHITELIST_IPS=
TRAEFIK_DASHBOARD_ENABLED=true
TRAEFIK_DASHBOARD_USER=admin
TRAEFIK_DASHBOARD_PASSWORD=hashed-password
```

## Port Mappings

### docker-compose.yml (Swarm)
Ports are managed by Traefik:
- `80` → HTTP (redirects to HTTPS)
- `443` → HTTPS (Traefik handles SSL)
- `5432` → PostgreSQL (TLS via Traefik)
- Kong port `8000` is internal only

### docker-compose.standalone.yml (Compose)
Direct port mapping:
- `8000` → Kong (no SSL)
- `5432` → PostgreSQL (no TLS) - if exposed

## Recommendations

### Use docker-compose.yml When:
- Deploying to production
- Need automatic SSL certificates
- Require high availability
- Running multiple servers
- Need advanced security features
- Want automatic scaling

### Use docker-compose.standalone.yml When:
- Local development
- Testing configurations
- Learning/evaluation
- Single developer environment
- Internal-only applications
- Quick prototyping

## Support

For issues specific to either configuration:
- Standalone issues: Check Docker Compose logs
- Production issues: Check both Traefik and service logs

```bash
# Standalone logs
docker compose -f docker-compose.standalone.yml logs [service]

# Production logs
docker service logs supabase_[service]
docker service logs supabase_traefik
```
