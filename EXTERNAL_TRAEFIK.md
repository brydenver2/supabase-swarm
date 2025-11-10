# Using External Traefik Instance

This guide explains how to use an existing Traefik instance instead of deploying the bundled Traefik service.

## When to Use External Traefik

You should use an external Traefik instance if:
- You already have Traefik running in your Docker Swarm cluster
- You want to share one Traefik instance across multiple applications
- You have custom Traefik configuration that you want to maintain
- You're integrating Supabase into an existing infrastructure

## Configuration Steps

### 1. Set Environment Variable

In your `.env` file, set:

```bash
DEPLOY_TRAEFIK=false
```

This tells the setup script to skip creating Traefik-related volumes and configs.

### 2. Remove or Comment Out Traefik Service

In `docker-compose.yml`, either:

**Option A: Comment out the entire traefik service**
```yaml
# =============================================================================
# Traefik - Load Balancer and SSL Termination
# =============================================================================
# COMMENTED OUT - Using external Traefik instance
# =============================================================================
#  traefik:
#    hostname: traefik
#    image: traefik:v3.2
#    ... (rest of the service)
```

**Option B: Remove the traefik service completely**
Delete lines 3-62 of docker-compose.yml (the entire traefik service section).

### 3. Keep Kong Labels

**Important:** Do NOT remove the Traefik labels from the Kong service. These labels tell your external Traefik where to route traffic. The labels remain active and will be discovered by your external Traefik instance.

The Kong service should still have these labels:
```yaml
  kong:
    # ... other configuration ...
    deploy:
      labels:
        - 'traefik.enable=true'
        - 'traefik.constraint-label=supabase_overlay'
        - 'traefik.docker.network=supabase_overlay'
        # ... all other Traefik labels ...
```

### 4. Configure Your External Traefik

Ensure your external Traefik is configured to:

**Watch the supabase_overlay network:**
```yaml
providers:
  swarm:
    endpoint: "unix:///var/run/docker.sock"
    network: supabase_overlay
    watch: true
```

**Have the required entrypoints:**
```yaml
entryPoints:
  http:
    address: ":80"
  https:
    address: ":443"
  postgres:
    address: ":5432"  # If you want PostgreSQL access
```

**Have a certificate resolver configured:**
```yaml
certificatesResolvers:
  letsencrypt:
    acme:
      email: your-email@example.com
      storage: /letsencrypt/acme.json
      tlsChallenge: {}
```

### 5. Connect to the Same Network

Make sure your external Traefik service is connected to the `supabase_overlay` network:

```yaml
services:
  traefik:
    # ... your Traefik configuration ...
    networks:
      - supabase_overlay

networks:
  supabase_overlay:
    external: true
```

### 6. Deploy Supabase

Run the setup script:
```bash
./setup.sh --swarm
```

Deploy the stack:
```bash
docker stack deploy -c docker-compose.yml supabase
```

## Verifying External Traefik Integration

### 1. Check Service Discovery

After deployment, verify that Traefik discovered the Kong service:

```bash
# Check Traefik logs
docker service logs <your-traefik-service-name> | grep kong

# You should see messages about discovering the supabase services
```

### 2. Check Routes

Access your Traefik dashboard (if enabled) and verify:
- HTTP router `supabase-http` exists
- HTTPS router `supabase-https` exists
- Service `supabase` exists with Kong backend

### 3. Test Access

```bash
# Test HTTP redirect
curl -I http://${TRAEFIK_DOMAIN}

# Should return 301 redirect to https

# Test HTTPS access
curl -I https://${TRAEFIK_DOMAIN}

# Should return 200 OK
```

## Environment Variables

When using external Traefik, you still need these environment variables:

```bash
# Required for routing
TRAEFIK_DOMAIN=your-domain.com

# Required for middleware configuration
TRAEFIK_RATE_LIMIT=100

# Optional for PostgreSQL access
TRAEFIK_POSTGRES_DOMAIN=postgres.your-domain.com

# NOT NEEDED when using external Traefik:
# TRAEFIK_ACME_EMAIL (your external Traefik handles certificates)
# TRAEFIK_DASHBOARD_USER (your external Traefik dashboard)
# TRAEFIK_DASHBOARD_PASSWORD (your external Traefik dashboard)
```

## Middleware Configuration

The Kong service labels define these middlewares:
- `https-redirect` - Redirects HTTP to HTTPS
- `rate-limit` - Rate limiting (configurable via TRAEFIK_RATE_LIMIT)
- `security-headers` - Security headers (HSTS, X-Frame-Options, etc.)

These middlewares are defined inline in the labels, so they work automatically with your external Traefik.

## Troubleshooting

### Routes Not Appearing

**Problem:** Your external Traefik doesn't discover the Kong service.

**Solutions:**
1. Verify Traefik is watching the correct network:
   ```bash
   docker service inspect <traefik-service> | grep -A5 Networks
   ```

2. Check Traefik provider configuration:
   ```bash
   docker service logs <traefik-service> | grep provider
   ```

3. Verify constraint labels match:
   ```bash
   # Check if constraint-label matches in both Traefik and Kong
   docker service inspect <traefik-service> | grep constraint
   docker service inspect supabase_kong | grep constraint
   ```

### Certificate Issues

**Problem:** SSL certificates not working with external Traefik.

**Solutions:**
1. Verify your external Traefik has a certificate resolver configured
2. Check that the resolver name matches in labels (default: `letsencrypt`)
3. Update Kong labels if your resolver has a different name:
   ```yaml
   - 'traefik.http.routers.supabase-https.tls.certresolver=your-resolver-name'
   ```

### Middleware Not Applied

**Problem:** Rate limiting or security headers not working.

**Solutions:**
1. Check middleware definition in Kong labels (they're inline)
2. Verify TRAEFIK_RATE_LIMIT environment variable is set
3. Check Traefik logs for middleware errors

## Advanced Configuration

### Custom Certificate Resolver

If your external Traefik uses a different certificate resolver name:

```bash
# In docker-compose.yml, update the Kong labels:
- 'traefik.http.routers.supabase-https.tls.certresolver=my-custom-resolver'
- 'traefik.http.routers.traefik-dashboard.tls.certresolver=my-custom-resolver'
```

### Different Entrypoint Names

If your external Traefik uses different entrypoint names:

```bash
# Update Kong labels in docker-compose.yml:
- 'traefik.http.routers.supabase-http.entrypoints=web'  # instead of 'http'
- 'traefik.http.routers.supabase-https.entrypoints=websecure'  # instead of 'https'
```

### Custom Middleware

To use additional middleware from your external Traefik:

```bash
# Add to Kong labels:
- 'traefik.http.routers.supabase-https.middlewares=rate-limit,security-headers,my-custom-middleware'
```

## Comparison: Bundled vs External Traefik

| Feature | Bundled Traefik | External Traefik |
|---------|----------------|------------------|
| Setup Complexity | Simple | Medium |
| Resource Usage | Dedicated for Supabase | Shared across apps |
| Configuration | Pre-configured | Custom configuration |
| Certificate Management | Automatic | Your responsibility |
| Updates | Update docker-compose.yml | Update your Traefik |
| Isolation | Isolated from other apps | Shared with other apps |

## Example: Complete External Traefik Setup

Here's a complete example of an external Traefik configuration that works with Supabase:

```yaml
version: '3.8'

services:
  traefik:
    image: traefik:v3.2
    command:
      - "--api.dashboard=true"
      - "--providers.swarm=true"
      - "--providers.swarm.endpoint=unix:///var/run/docker.sock"
      - "--providers.swarm.network=supabase_overlay"
      - "--entrypoints.http.address=:80"
      - "--entrypoints.https.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.email=admin@example.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik-certificates:/letsencrypt
    networks:
      - supabase_overlay
    deploy:
      placement:
        constraints:
          - node.role == manager

networks:
  supabase_overlay:
    external: true

volumes:
  traefik-certificates:
    external: true
```

## Support

For issues with external Traefik integration:
1. Check [Traefik Docker Swarm documentation](https://doc.traefik.io/traefik/providers/docker/)
2. Review [Traefik routing documentation](https://doc.traefik.io/traefik/routing/overview/)
3. Verify network connectivity between Traefik and Kong
4. Check Traefik and Kong service logs

## Summary

Using an external Traefik instance is straightforward:
1. Set `DEPLOY_TRAEFIK=false` in .env
2. Comment out/remove the traefik service from docker-compose.yml
3. Keep all Kong labels intact
4. Ensure your external Traefik watches the supabase_overlay network
5. Deploy normally

The Kong service labels provide all the routing information your external Traefik needs to route traffic correctly.
