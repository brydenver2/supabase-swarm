# Traefik v3 Load Balancer Integration

This document describes the Traefik v3 integration for secure load balancing and SSL termination.

## Features

### Load Balancing with Traefik v3
- **Modern Load Balancer**: Upgraded to Traefik v3.2 for enhanced performance and security
- **Automatic SSL/TLS**: Let's Encrypt integration for automatic certificate management
- **High Availability**: Supports Docker Swarm mode for multi-server deployments

### Security Features
- **SSL/TLS Encryption**: Automatic HTTPS with Let's Encrypt certificates
- **Rate Limiting**: Configurable request rate limiting to prevent abuse
- **Security Headers**: Automatic security headers (HSTS, X-Frame-Options, etc.)
- **HTTPS Redirect**: Automatic HTTP to HTTPS redirection
- **Secure Database Access**: TLS-enabled PostgreSQL connections

### Middleware Stack
1. **HTTPS Redirect**: Automatically redirects HTTP to HTTPS
2. **Rate Limiting**: Configurable rate limits per IP address
3. **Security Headers**: 
   - Strict-Transport-Security (HSTS)
   - X-Frame-Options: SAMEORIGIN
   - X-Content-Type-Options: nosniff
   - X-XSS-Protection
   - Referrer-Policy: strict-origin-when-cross-origin
4. **IP Whitelisting** (optional): Restrict access to specific IP addresses

## Configuration

### Environment Variables

Add these variables to your `.env` file:

```bash
# Traefik Domain Configuration
TRAEFIK_DOMAIN=your-domain.com
TRAEFIK_POSTGRES_DOMAIN=postgres.your-domain.com

# SSL/TLS Configuration
TRAEFIK_ACME_EMAIL=admin@your-domain.com
TRAEFIK_ACME_PRODUCTION=true  # false for staging/testing

# Security Settings
TRAEFIK_RATE_LIMIT=100  # requests per second
TRAEFIK_WHITELIST_IPS=  # comma-separated IPs (optional)

# Dashboard Access
TRAEFIK_DASHBOARD_ENABLED=true
TRAEFIK_DASHBOARD_USER=admin
TRAEFIK_DASHBOARD_PASSWORD=your-secure-password
```

### Setup Process

1. **Configure Environment Variables**:
   ```bash
   cp environment-variables.txt .env
   # Edit .env with your domain and email
   ```

2. **Run Setup Script**:
   ```bash
   ./setup.sh --swarm
   ```

3. **Deploy Stack**:
   ```bash
   ./deploy-swarm.sh
   ```

### Access Points

Once deployed:
- **Supabase**: `https://your-domain.com`
- **Traefik Dashboard**: `https://traefik.your-domain.com`
- **PostgreSQL** (with TLS): `postgres.your-domain.com:5432`

## Security Best Practices

1. **Use Strong Passwords**: Generate secure passwords for Traefik dashboard
   ```bash
   htpasswd -nb admin $(openssl rand -base64 16)
   ```

2. **Enable Production SSL**: Set `TRAEFIK_ACME_PRODUCTION=true` for production

3. **Configure Rate Limits**: Adjust `TRAEFIK_RATE_LIMIT` based on your needs

4. **Enable IP Whitelisting**: For admin access, consider IP restrictions

5. **Monitor Logs**: Check Traefik logs regularly for security events

## Troubleshooting

### Certificate Issues
- Verify DNS is pointing to your server
- Check Let's Encrypt rate limits
- Use staging environment for testing

### Rate Limiting
- Adjust `TRAEFIK_RATE_LIMIT` if legitimate traffic is being blocked
- Check access logs for patterns

### TLS Configuration
- Ensure ports 80 and 443 are open on your firewall
- Verify domain DNS records are correct
- Check Traefik logs for certificate errors

## External Database Support

See [EXTERNAL_DATABASE.md](./EXTERNAL_DATABASE.md) for details on using external databases.
