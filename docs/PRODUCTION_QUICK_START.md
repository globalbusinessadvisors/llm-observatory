# Production Quick Start Guide

Fast-track guide to deploy LLM Observatory to production in under 1 hour.

## Prerequisites Checklist

- [ ] Ubuntu 22.04 LTS server (16GB RAM, 8 cores, 500GB SSD minimum)
- [ ] Domain name configured (e.g., observatory.yourdomain.com)
- [ ] SSL certificate ready (Let's Encrypt or commercial)
- [ ] SMTP credentials for alerts
- [ ] AWS account (optional, for S3 backups)

## 1. Server Setup (10 minutes)

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Log out and back in for group membership
exit
```

## 2. System Optimization (5 minutes)

```bash
# Increase file limits
sudo tee -a /etc/security/limits.conf <<EOF
* soft nofile 65536
* hard nofile 65536
EOF

# Optimize kernel
sudo tee -a /etc/sysctl.conf <<EOF
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
vm.swappiness = 10
vm.overcommit_memory = 1
EOF

sudo sysctl -p

# Disable transparent huge pages
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
```

## 3. Clone Repository (2 minutes)

```bash
cd /opt
sudo git clone https://github.com/llm-observatory/llm-observatory.git
sudo chown -R $USER:$USER llm-observatory
cd llm-observatory
```

## 4. Generate Secrets (3 minutes)

```bash
# Create secrets directory
mkdir -p secrets
chmod 700 secrets

# Generate all secrets
cat > generate-secrets.sh <<'EOF'
#!/bin/bash
openssl rand -base64 32 > secrets/db_password.txt
openssl rand -base64 32 > secrets/db_app_password.txt
openssl rand -base64 32 > secrets/db_readonly_password.txt
openssl rand -base64 32 > secrets/db_replication_password.txt
openssl rand -base64 32 > secrets/redis_password.txt
openssl rand -base64 32 > secrets/grafana_admin_password.txt
openssl rand -hex 32 > secrets/grafana_secret_key.txt
openssl rand -hex 32 > secrets/secret_key.txt
openssl rand -hex 32 > secrets/jwt_secret.txt
openssl rand -hex 32 > secrets/backup_encryption_key.txt

echo "postgres" > secrets/db_user.txt
echo "admin" > secrets/grafana_admin_user.txt

# Generate connection strings
DB_USER=$(cat secrets/db_user.txt)
DB_PASSWORD=$(cat secrets/db_password.txt)
echo "postgresql://${DB_USER}:${DB_PASSWORD}@timescaledb-primary:5432/llm_observatory" > secrets/database_url.txt

REDIS_PASSWORD=$(cat secrets/redis_password.txt)
echo "redis://:${REDIS_PASSWORD}@redis-master:6379/0" > secrets/redis_url.txt

chmod 600 secrets/*.txt
echo "Secrets generated successfully!"
EOF

chmod +x generate-secrets.sh
./generate-secrets.sh
```

## 5. SSL Certificates (5 minutes)

### Option A: Let's Encrypt (Recommended)

```bash
# Install certbot
sudo apt install -y certbot

# Stop any web server
sudo systemctl stop nginx 2>/dev/null || true

# Obtain certificate
sudo certbot certonly --standalone \
  -d observatory.yourdomain.com \
  -d api.observatory.yourdomain.com \
  --email admin@yourdomain.com \
  --agree-tos \
  --no-eff-email

# Copy certificates
sudo mkdir -p docker/certs/nginx
sudo cp /etc/letsencrypt/live/observatory.yourdomain.com/fullchain.pem docker/certs/nginx/server.crt
sudo cp /etc/letsencrypt/live/observatory.yourdomain.com/privkey.pem docker/certs/nginx/server.key
sudo cp /etc/letsencrypt/live/observatory.yourdomain.com/chain.pem docker/certs/nginx/ca.crt
sudo chown -R $USER:$USER docker/certs
```

### Option B: Self-Signed (Testing Only)

```bash
mkdir -p docker/certs/nginx

openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
  -keyout docker/certs/nginx/server.key \
  -out docker/certs/nginx/server.crt \
  -subj "/CN=observatory.yourdomain.com"

cp docker/certs/nginx/server.crt docker/certs/nginx/ca.crt
```

## 6. Configure Environment (5 minutes)

```bash
# Copy template
cp .env.production.example .env.production

# Edit configuration
nano .env.production
```

**Minimum required changes:**

```bash
# Update these values in .env.production:
GRAFANA_ROOT_URL=https://observatory.yourdomain.com
GRAFANA_DOMAIN=observatory.yourdomain.com
CORS_ORIGINS=https://observatory.yourdomain.com,https://api.observatory.yourdomain.com

# SMTP settings (for alerts)
SMTP_ENABLED=true
SMTP_HOST=smtp.yourdomain.com
SMTP_USER=notifications@yourdomain.com
NOTIFICATION_EMAIL=alerts@yourdomain.com

# Add SMTP password to secrets
echo "your-smtp-password" > secrets/smtp_password.txt

# Optional: AWS S3 for backups
S3_BACKUP_BUCKET=llm-observatory-backups
AWS_REGION=us-east-1
echo "your-aws-key" > secrets/aws_access_key_id.txt
echo "your-aws-secret" > secrets/aws_secret_access_key.txt
```

## 7. Create Data Directories (2 minutes)

```bash
sudo mkdir -p /var/lib/llm-observatory/{timescaledb-primary,redis-master,grafana,backups,wal_archive,nginx-logs}
sudo chown -R 1000:1000 /var/lib/llm-observatory
```

## 8. Configure Nginx (3 minutes)

```bash
# Create nginx directories
mkdir -p docker/nginx/conf.d

# Create nginx configuration
cat > docker/nginx/nginx.prod.conf <<'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 4096;
    use epoll;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    keepalive_timeout 65;
    gzip on;

    include /etc/nginx/conf.d/*.conf;
}
EOF

# Update domain in docker-compose
export YOUR_DOMAIN="observatory.yourdomain.com"
```

## 9. Deploy Services (10 minutes)

```bash
# Load environment
export $(cat .env.production | xargs)

# Pull images
docker compose -f docker-compose.prod.yml pull

# Start infrastructure services
docker compose -f docker-compose.prod.yml up -d timescaledb-primary redis-master

# Wait for database (about 30 seconds)
echo "Waiting for database to be ready..."
until docker exec llm-observatory-db-primary pg_isready -U postgres 2>/dev/null; do
  echo -n "."
  sleep 2
done
echo " Ready!"

# Start application services
docker compose -f docker-compose.prod.yml up -d

# Check status
docker compose -f docker-compose.prod.yml ps
```

## 10. Verify Deployment (5 minutes)

```bash
# Check all containers are healthy
docker ps --format "table {{.Names}}\t{{.Status}}"

# Test database
docker exec llm-observatory-db-primary psql -U postgres -c "SELECT version();"

# Test Redis
docker exec llm-observatory-redis-master redis-cli -a "$(cat secrets/redis_password.txt)" PING

# Test API health (wait 30 seconds for services to start)
sleep 30
curl -k https://api.observatory.yourdomain.com/health

# Test Grafana
curl -k https://observatory.yourdomain.com/api/health

# View logs
docker compose -f docker-compose.prod.yml logs -f --tail=50
```

## 11. Access Services

**Grafana Dashboard:**
- URL: https://observatory.yourdomain.com
- Username: `admin`
- Password: `cat secrets/grafana_admin_password.txt`

**API Endpoint:**
- URL: https://api.observatory.yourdomain.com
- Health: https://api.observatory.yourdomain.com/health
- Metrics: https://api.observatory.yourdomain.com/metrics

## 12. Setup Backups (5 minutes)

```bash
# Test manual backup
docker compose -f docker-compose.prod.yml --profile backup run --rm backup

# Verify backup created
ls -lh /var/lib/llm-observatory/backups/

# Setup automated backups
crontab -e
```

Add:

```cron
# Daily backup at 2 AM
0 2 * * * cd /opt/llm-observatory && docker compose -f docker-compose.prod.yml --profile backup run --rm backup >> /var/log/llm-obs-backup.log 2>&1
```

## 13. Configure Firewall (3 minutes)

```bash
# Setup UFW
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# Install fail2ban
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

## 14. Setup Monitoring (5 minutes)

```bash
# Access Grafana
GRAFANA_PASS=$(cat secrets/grafana_admin_password.txt)
echo "Grafana admin password: $GRAFANA_PASS"
echo "Login at: https://observatory.yourdomain.com"

# Configure datasource (in Grafana UI)
# 1. Go to Configuration > Data Sources
# 2. Add PostgreSQL datasource:
#    - Host: timescaledb-primary:5432
#    - Database: llm_observatory
#    - User: postgres
#    - Password: (from secrets/db_password.txt)
#    - SSL Mode: require

# Import dashboards from docker/grafana/dashboards/
```

## Post-Deployment Tasks

### Immediate (Today)

- [ ] Change default Grafana password
- [ ] Test backup and restore procedure
- [ ] Configure monitoring alerts
- [ ] Test SSL certificate renewal
- [ ] Document any customizations
- [ ] Share credentials with team (securely)

### Within 1 Week

- [ ] Setup log aggregation
- [ ] Configure error tracking (Sentry)
- [ ] Enable auto-scaling (if needed)
- [ ] Performance baseline testing
- [ ] Load testing
- [ ] Security audit

### Within 1 Month

- [ ] Review and optimize resource usage
- [ ] Implement database retention policies
- [ ] Setup multi-region (if needed)
- [ ] Disaster recovery drill
- [ ] Team training session

## Troubleshooting

### Services won't start

```bash
# Check logs
docker compose -f docker-compose.prod.yml logs

# Check resources
docker stats
df -h
free -h

# Restart services
docker compose -f docker-compose.prod.yml restart
```

### Cannot access via HTTPS

```bash
# Check nginx
docker logs llm-observatory-nginx

# Test nginx config
docker exec llm-observatory-nginx nginx -t

# Check firewall
sudo ufw status

# Check DNS
nslookup observatory.yourdomain.com
```

### Database connection failed

```bash
# Check database status
docker exec llm-observatory-db-primary pg_isready -U postgres

# Check database logs
docker logs llm-observatory-db-primary

# Check connection string
cat secrets/database_url.txt
```

## Getting Help

- **Documentation**: [PRODUCTION_DEPLOYMENT.md](./PRODUCTION_DEPLOYMENT.md)
- **Checklist**: [PRODUCTION_CHECKLIST.md](./PRODUCTION_CHECKLIST.md)
- **Operations**: [OPERATIONS_MANUAL.md](./OPERATIONS_MANUAL.md)
- **GitHub Issues**: https://github.com/llm-observatory/llm-observatory/issues

## Quick Commands Reference

```bash
# View all services
docker compose -f docker-compose.prod.yml ps

# View logs
docker compose -f docker-compose.prod.yml logs -f

# Restart service
docker compose -f docker-compose.prod.yml restart api-server

# Stop all services
docker compose -f docker-compose.prod.yml down

# Start all services
docker compose -f docker-compose.prod.yml up -d

# Scale API servers
docker compose -f docker-compose.prod.yml up -d --scale api-server=4

# Manual backup
docker compose -f docker-compose.prod.yml --profile backup run --rm backup

# Database shell
docker exec -it llm-observatory-db-primary psql -U postgres -d llm_observatory

# Redis shell
docker exec -it llm-observatory-redis-master redis-cli -a "$(cat secrets/redis_password.txt)"

# Check resource usage
docker stats

# Update services
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

## Security Hardening Checklist

- [ ] All default passwords changed
- [ ] Strong random secrets generated
- [ ] SSL/TLS enabled and working
- [ ] Firewall configured (only 80/443 open)
- [ ] fail2ban enabled
- [ ] Non-root users for all containers
- [ ] Read-only filesystems where possible
- [ ] Regular security updates scheduled
- [ ] Audit logging enabled
- [ ] Backups encrypted
- [ ] Secret rotation policy established

## Success Criteria

Your deployment is successful when:

1. All containers show "healthy" status
2. Grafana UI loads and shows data
3. API health endpoint returns 200 OK
4. Database queries execute successfully
5. Redis responds to PING
6. SSL certificate is valid and trusted
7. Backups complete successfully
8. Monitoring alerts are configured
9. No errors in logs
10. Team can access the system

---

**Estimated Total Time**: 60 minutes

**Next Steps**: [Production Checklist](./PRODUCTION_CHECKLIST.md)
