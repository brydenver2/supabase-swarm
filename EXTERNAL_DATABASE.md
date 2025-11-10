# External Database Configuration

This guide explains how to configure Supabase to use an external PostgreSQL database instead of the bundled container.

## Why Use an External Database?

- **Managed Services**: Use cloud provider managed databases (AWS RDS, Google Cloud SQL, Azure Database)
- **High Availability**: Leverage database clustering and replication
- **Backup & Recovery**: Use provider-managed backup solutions
- **Performance**: Dedicated database resources
- **Compliance**: Meet regulatory requirements with certified database services

## Prerequisites

- PostgreSQL 15.x or higher
- Superuser access to create roles and schemas
- Network connectivity from Supabase containers to database
- SSL/TLS support (recommended)

## Configuration Steps

### 1. Configure Environment Variables

In your `.env` file, set:

```bash
# Enable external database mode
USE_EXTERNAL_DB=true

# External database connection details
EXTERNAL_POSTGRES_HOST=your-db-host.com
EXTERNAL_POSTGRES_PORT=5432
EXTERNAL_POSTGRES_DB=postgres
EXTERNAL_POSTGRES_PASSWORD=your-secure-password
EXTERNAL_POSTGRES_USER=postgres

# Update POSTGRES_HOST to point to external DB
POSTGRES_HOST=your-db-host.com
POSTGRES_PORT=5432
POSTGRES_DB=postgres
POSTGRES_PASSWORD=your-secure-password
```

### 2. Initialize External Database

Run the initialization SQL scripts on your external database:

```bash
# Connect to your external database
psql -h your-db-host.com -U postgres -d postgres

# Run initialization scripts in order:
\i volumes/db/roles.sql
\i volumes/db/jwt.sql
\i volumes/db/webhooks.sql
\i volumes/db/_supabase.sql
\i volumes/db/pooler.sql
\i volumes/db/realtime.sql
\i volumes/db/logs.sql
```

Or use a script:

```bash
for script in volumes/db/roles.sql volumes/db/jwt.sql volumes/db/webhooks.sql volumes/db/_supabase.sql volumes/db/pooler.sql volumes/db/realtime.sql volumes/db/logs.sql; do
  psql -h your-db-host.com -U postgres -d postgres -f $script
done
```

### 3. Run Setup with External DB Flag

```bash
./setup.sh --swarm --external-db
```

This will:
- Skip creating internal database volumes
- Validate external database configuration
- Create other required resources

### 4. Deploy Supabase

For Docker Swarm:
```bash
# Remove the db service from deployment
docker stack deploy -c docker-compose.yml supabase
```

For Docker Compose:
```bash
# Edit docker-compose.standalone.yml to comment out or remove the db service
docker-compose -f docker-compose.standalone.yml up -d
```

## Database Requirements

### Required PostgreSQL Extensions

Ensure these extensions are enabled:

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pgjwt";
CREATE EXTENSION IF NOT EXISTS "pg_net";
```

### Required Roles

The initialization scripts create these roles:
- `supabase_admin`
- `supabase_auth_admin`
- `supabase_storage_admin`
- `authenticator`
- `anon`
- `authenticated`
- `service_role`

### Required Schemas

- `auth` - Authentication data
- `storage` - File storage metadata
- `realtime` - Real-time subscriptions
- `_analytics` - Analytics data
- `_realtime` - Realtime internal
- `public` - User data (default)
- `graphql_public` - GraphQL schema

## Security Considerations

### SSL/TLS Connection

For production, always use SSL:

```bash
# Add SSL parameters to connection strings
GOTRUE_DB_DATABASE_URL=postgres://supabase_auth_admin:PASSWORD@HOST:5432/DB?sslmode=require
```

### Network Security

- Use private networking between Supabase and database
- Configure firewall rules to allow only Supabase IPs
- Use VPC peering or private endpoints when possible

### Credentials Management

- Use strong, unique passwords (32+ characters)
- Rotate credentials regularly
- Use secrets management (Docker secrets, AWS Secrets Manager, etc.)
- Never commit credentials to version control

## Monitoring & Maintenance

### Connection Pooling

Configure connection pool sizes based on your database limits:

```bash
# In database server configuration
max_connections = 200
```

### Health Checks

Monitor database health:
- Connection count
- Query performance
- Disk usage
- Replication lag (if using replicas)

### Backup Strategy

Ensure your external database has:
- Automated daily backups
- Point-in-time recovery capability
- Backup retention policy
- Tested restore procedures

## Troubleshooting

### Connection Issues

```bash
# Test database connectivity
docker exec -it <container> psql -h $POSTGRES_HOST -U postgres -d $POSTGRES_DB

# Check network connectivity
docker exec -it <container> ping $POSTGRES_HOST

# Verify DNS resolution
docker exec -it <container> nslookup $POSTGRES_HOST
```

### Permission Issues

```bash
# Verify roles exist
SELECT rolname FROM pg_roles;

# Check schema permissions
SELECT schema_name FROM information_schema.schemata;
```

### SSL Certificate Issues

```bash
# Test SSL connection
psql "postgresql://user:pass@host:5432/db?sslmode=require"

# Check certificate validity
openssl s_client -connect host:5432 -starttls postgres
```

## Migration from Internal to External Database

To migrate from the bundled database to external:

1. **Backup Internal Database**:
   ```bash
   docker exec supabase-db pg_dump -U postgres > backup.sql
   ```

2. **Restore to External Database**:
   ```bash
   psql -h external-host -U postgres -d postgres < backup.sql
   ```

3. **Update Configuration**:
   - Set `USE_EXTERNAL_DB=true`
   - Configure external database credentials
   - Update `POSTGRES_HOST`

4. **Restart Services**:
   ```bash
   docker stack deploy -c docker-compose.yml supabase
   ```

## Cloud Provider Examples

### AWS RDS

```bash
EXTERNAL_POSTGRES_HOST=mydb.abc123.us-east-1.rds.amazonaws.com
EXTERNAL_POSTGRES_PORT=5432
EXTERNAL_POSTGRES_DB=postgres
```

### Google Cloud SQL

```bash
EXTERNAL_POSTGRES_HOST=34.123.45.67
EXTERNAL_POSTGRES_PORT=5432
# Or use Cloud SQL Proxy for better security
```

### Azure Database for PostgreSQL

```bash
EXTERNAL_POSTGRES_HOST=myserver.postgres.database.azure.com
EXTERNAL_POSTGRES_PORT=5432
EXTERNAL_POSTGRES_USER=adminuser@myserver
```

### DigitalOcean Managed Database

```bash
EXTERNAL_POSTGRES_HOST=db-postgresql-nyc3-12345.ondigitalocean.com
EXTERNAL_POSTGRES_PORT=25060
```

## Support

For issues with external database configuration:
1. Check database logs
2. Verify network connectivity
3. Ensure all initialization scripts ran successfully
4. Review Supabase service logs
5. Consult cloud provider documentation for managed databases
