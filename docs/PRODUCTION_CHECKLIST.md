# Production Deployment Checklist

Comprehensive checklist for deploying LLM Observatory to production. Use this to ensure all critical steps are completed and verified.

## Pre-Deployment Checklist

### Infrastructure Preparation

#### Server Setup
- [ ] Server provisioned with adequate resources (CPU: 8+ cores, RAM: 16GB+, Disk: 500GB+ SSD)
- [ ] Operating system installed and updated (Ubuntu 22.04 LTS recommended)
- [ ] Static IP address assigned or Elastic IP attached
- [ ] DNS records configured and propagated
  - [ ] `observatory.yourdomain.com` → Server IP
  - [ ] `api.observatory.yourdomain.com` → Server IP
- [ ] Firewall ports configured (80, 443 open; all others blocked)
- [ ] SSH key-based authentication configured
- [ ] Root/sudo access configured properly
- [ ] Timezone set correctly (`timedatectl set-timezone UTC`)

#### System Optimization
- [ ] File descriptor limits increased (`/etc/security/limits.conf`)
- [ ] Kernel parameters optimized (`/etc/sysctl.conf`)
  - [ ] Network parameters tuned
  - [ ] Memory parameters configured
  - [ ] PostgreSQL-specific parameters set
- [ ] Transparent Huge Pages (THP) disabled
- [ ] Swap configured appropriately (10GB recommended, swappiness=10)
- [ ] Log rotation configured (`/etc/logrotate.d/`)
- [ ] NTP/chrony configured for time synchronization
- [ ] Unattended upgrades enabled for security patches

#### Storage Configuration
- [ ] Data directories created (`/var/lib/llm-observatory/*`)
- [ ] Proper permissions set (1000:1000 for application data)
- [ ] Separate volumes mounted for database and backups
- [ ] RAID configured for database volumes (if applicable)
- [ ] Backup storage provisioned (local + S3/cloud)
- [ ] Disk monitoring enabled (space and I/O)

#### Network Configuration
- [ ] Network interface configured with proper MTU
- [ ] Load balancer configured (if using)
- [ ] CDN configured for static assets (if applicable)
- [ ] DDoS protection enabled (CloudFlare, AWS Shield, etc.)
- [ ] Network monitoring enabled

### Software Installation

#### Docker Environment
- [ ] Docker Engine installed (version 24.0+)
- [ ] Docker Compose installed (version 2.20+)
- [ ] Docker daemon configured properly
  - [ ] Logging driver configured
  - [ ] Storage driver optimized (overlay2)
  - [ ] Insecure registries configured (if needed)
- [ ] Docker service enabled and running
- [ ] User added to docker group
- [ ] Docker resource limits configured
- [ ] Docker networks configured (bridge, custom)

#### Additional Tools
- [ ] Git installed
- [ ] OpenSSL installed (3.0+)
- [ ] curl/wget installed
- [ ] htop/iotop installed
- [ ] ncdu installed (disk usage analyzer)
- [ ] netstat/ss installed
- [ ] fail2ban installed and configured
- [ ] logrotate configured
- [ ] monitoring agent installed (if using external monitoring)

### Security Configuration

#### Secrets Generation
- [ ] All secrets generated with strong randomness
  - [ ] Database passwords (32+ characters)
  - [ ] Redis password (32+ characters)
  - [ ] Application secret keys (64+ hex characters)
  - [ ] JWT secrets (64+ hex characters)
  - [ ] Grafana admin password (32+ characters)
  - [ ] Backup encryption key (64+ hex characters)
- [ ] Secrets stored securely
  - [ ] File permissions set to 600
  - [ ] Secrets directory permissions set to 700
  - [ ] Secrets not committed to version control
- [ ] External secret manager configured (AWS Secrets Manager, Vault)
- [ ] Secret rotation policy documented
- [ ] Secret backup procedure established

#### SSL/TLS Certificates
- [ ] SSL certificates obtained
  - [ ] Let's Encrypt certificates issued (for public domains)
  - [ ] Or: Commercial certificates purchased
  - [ ] Or: Self-signed certificates generated (internal only)
- [ ] Certificates copied to proper locations
  - [ ] Nginx certificates (`docker/certs/nginx/`)
  - [ ] PostgreSQL certificates (`docker/certs/postgres/`)
  - [ ] Redis certificates (`docker/certs/redis/`)
  - [ ] API certificates (`docker/certs/api/`)
  - [ ] Grafana certificates (`docker/certs/grafana/`)
- [ ] Certificate permissions set correctly (644 for .crt, 600 for .key)
- [ ] Certificate chain validated
- [ ] Certificate expiry monitoring configured
- [ ] Auto-renewal configured (certbot timer for Let's Encrypt)
- [ ] Post-renewal hooks configured

#### Firewall Configuration
- [ ] UFW or iptables configured
  - [ ] Default deny incoming
  - [ ] Default allow outgoing
  - [ ] SSH allowed (with rate limiting)
  - [ ] HTTP (80) allowed
  - [ ] HTTPS (443) allowed
  - [ ] All other ports blocked
- [ ] fail2ban configured
  - [ ] SSH jail enabled
  - [ ] Nginx jail enabled
  - [ ] PostgreSQL jail enabled (optional)
- [ ] Port scanning protection enabled
- [ ] IP reputation filtering configured (optional)

#### Access Control
- [ ] SSH hardened
  - [ ] Password authentication disabled
  - [ ] Root login disabled
  - [ ] Key-based authentication only
  - [ ] SSH port changed (optional, not 22)
  - [ ] SSH timeout configured
- [ ] User accounts configured
  - [ ] Deployment user created
  - [ ] Sudo access configured properly
  - [ ] Password policy enforced
- [ ] Audit logging enabled
  - [ ] auditd configured
  - [ ] sudo logging enabled
  - [ ] Docker events logged

### Application Configuration

#### Environment Configuration
- [ ] `.env.production` file created from template
- [ ] All environment variables configured
  - [ ] Database settings
  - [ ] Redis settings
  - [ ] Application settings
  - [ ] Security settings
  - [ ] Monitoring settings
  - [ ] Backup settings
- [ ] Domain names updated in configuration
- [ ] CORS origins configured correctly
- [ ] Rate limits configured appropriately
- [ ] Resource limits configured (CPU, memory)
- [ ] Log levels set appropriately (info or warn)

#### Docker Configuration
- [ ] `docker-compose.prod.yml` reviewed
- [ ] Resource limits configured per service
- [ ] Health checks configured for all services
- [ ] Restart policies set to "always" for critical services
- [ ] Networks configured properly (frontend, backend isolated)
- [ ] Volumes configured with proper paths
- [ ] Secrets configured (Docker secrets or external)
- [ ] Logging configured with size and rotation limits

#### Database Configuration
- [ ] PostgreSQL configuration reviewed (`postgresql.prod.conf`)
  - [ ] Memory settings optimized for server specs
  - [ ] Connection limits set appropriately
  - [ ] WAL settings configured for replication
  - [ ] SSL/TLS enabled
  - [ ] Logging configured
- [ ] TimescaleDB settings configured
  - [ ] Retention policies defined
  - [ ] Compression policies configured
  - [ ] Continuous aggregates planned
- [ ] Database users created
  - [ ] Admin user (postgres)
  - [ ] Application user (llm_observatory_app)
  - [ ] Read-only user (llm_observatory_readonly)
  - [ ] Replication user (if using replicas)
- [ ] Database permissions verified
- [ ] Connection pooling configured

#### Backup Configuration
- [ ] Backup schedule defined
  - [ ] Daily incremental backups
  - [ ] Weekly full backups
  - [ ] Monthly archive backups
- [ ] Backup retention policy set (30+ days)
- [ ] S3 bucket created and configured
  - [ ] Bucket versioning enabled
  - [ ] Lifecycle policies configured
  - [ ] Encryption at rest enabled
  - [ ] IAM roles/policies configured
- [ ] WAL archiving configured for PITR
- [ ] Backup encryption enabled
- [ ] Backup verification process established
- [ ] Restore procedure documented and tested

### External Services

#### Cloud Services (if applicable)
- [ ] AWS/GCP/Azure account configured
  - [ ] IAM roles/service accounts created
  - [ ] Permissions granted (S3, Secrets Manager, etc.)
  - [ ] Billing alerts configured
- [ ] S3 buckets created
  - [ ] Backup bucket
  - [ ] WAL archive bucket
  - [ ] Log archive bucket (optional)
- [ ] CloudWatch/Cloud Logging configured
- [ ] CloudFront/CDN configured (if needed)

#### Email/SMTP
- [ ] SMTP server configured
  - [ ] SendGrid/SES/Mailgun account created
  - [ ] API keys generated
  - [ ] Sender email verified
  - [ ] SPF/DKIM/DMARC records configured
- [ ] Test email sent and verified
- [ ] Email templates configured
- [ ] Alert email recipients configured

#### Monitoring Services
- [ ] External monitoring configured (optional)
  - [ ] Datadog/New Relic/CloudWatch agent installed
  - [ ] Metrics collection configured
  - [ ] Log forwarding configured
- [ ] Error tracking configured
  - [ ] Sentry DSN configured
  - [ ] Error alerts configured
- [ ] APM configured (optional)
  - [ ] Distributed tracing enabled
  - [ ] Performance monitoring enabled
- [ ] Uptime monitoring configured
  - [ ] UptimeRobot/Pingdom checks configured
  - [ ] Status page created (optional)

## Deployment Checklist

### Pre-Deployment Validation

#### Code Preparation
- [ ] Latest code pulled from repository
  - [ ] Correct branch/tag checked out
  - [ ] Version verified
- [ ] Dependencies reviewed
  - [ ] Docker images available
  - [ ] Base images up to date
- [ ] Configuration files validated
  - [ ] YAML syntax validated
  - [ ] Environment variables syntax checked
  - [ ] No placeholder values remaining

#### Pre-Flight Checks
- [ ] Available disk space checked (`df -h`)
- [ ] Available memory checked (`free -h`)
- [ ] CPU cores verified (`nproc`)
- [ ] Docker daemon running (`docker info`)
- [ ] Docker Compose working (`docker compose version`)
- [ ] Network connectivity verified
- [ ] DNS resolution working
- [ ] Port availability checked
  - [ ] `netstat -tlnp | grep -E ':(80|443|5432|6379|3000|8080)'`
- [ ] Certificates validated
  - [ ] Not expired
  - [ ] Correct domain names
  - [ ] Chain complete
- [ ] Secrets exist and are readable
  - [ ] All files in `secrets/` directory exist
  - [ ] Permissions correct (600)
  - [ ] Content is non-empty

#### Docker Validation
- [ ] Docker Compose configuration validated
  - [ ] `docker compose -f docker-compose.prod.yml config`
  - [ ] No errors or warnings
- [ ] Docker images available
  - [ ] Base images pulled
  - [ ] Custom images built (if applicable)
- [ ] Docker networks available
- [ ] Docker volumes mountable

### Initial Deployment

#### Infrastructure Services
- [ ] Start database first
  ```bash
  docker compose -f docker-compose.prod.yml up -d timescaledb-primary
  ```
- [ ] Verify database health
  ```bash
  docker exec llm-observatory-db-primary pg_isready -U postgres
  ```
- [ ] Check database logs for errors
  ```bash
  docker logs llm-observatory-db-primary
  ```
- [ ] Verify TimescaleDB extension
  ```bash
  docker exec llm-observatory-db-primary psql -U postgres -d llm_observatory -c "\dx"
  ```

- [ ] Start Redis
  ```bash
  docker compose -f docker-compose.prod.yml up -d redis-master
  ```
- [ ] Verify Redis health
  ```bash
  docker exec llm-observatory-redis-master redis-cli -a "$(cat secrets/redis_password.txt)" PING
  ```

#### Database Initialization
- [ ] Run database migrations
  ```bash
  docker compose -f docker-compose.prod.yml run --rm api-server /app/bin/migrate up
  ```
- [ ] Verify schema created
- [ ] Verify hypertables created
- [ ] Create initial admin user (if applicable)
- [ ] Seed initial data (if needed)

#### Application Services
- [ ] Start Grafana
  ```bash
  docker compose -f docker-compose.prod.yml up -d grafana
  ```
- [ ] Verify Grafana health
- [ ] Test Grafana login
- [ ] Configure Grafana datasources
- [ ] Import Grafana dashboards

- [ ] Start API server
  ```bash
  docker compose -f docker-compose.prod.yml up -d api-server
  ```
- [ ] Verify API health
  ```bash
  curl -k https://api.observatory.yourdomain.com/health
  ```
- [ ] Check API logs for errors

- [ ] Start collector service
  ```bash
  docker compose -f docker-compose.prod.yml up -d collector
  ```
- [ ] Verify collector health
- [ ] Test OTLP endpoint

#### Reverse Proxy
- [ ] Start Nginx
  ```bash
  docker compose -f docker-compose.prod.yml up -d nginx
  ```
- [ ] Verify Nginx configuration
  ```bash
  docker exec llm-observatory-nginx nginx -t
  ```
- [ ] Check Nginx logs
- [ ] Test HTTP to HTTPS redirect
- [ ] Verify SSL/TLS working
- [ ] Test API endpoint through proxy
- [ ] Test Grafana endpoint through proxy

#### High Availability (Optional)
- [ ] Start read replica
  ```bash
  docker compose -f docker-compose.prod.yml --profile with-replica up -d timescaledb-replica
  ```
- [ ] Verify replication working
  ```bash
  docker exec llm-observatory-db-primary psql -U postgres -c "SELECT * FROM pg_stat_replication;"
  ```
- [ ] Test read queries on replica

- [ ] Start Redis Sentinel
  ```bash
  docker compose -f docker-compose.prod.yml --profile with-ha up -d redis-sentinel
  ```
- [ ] Verify Sentinel working
  ```bash
  docker exec llm-observatory-redis-sentinel redis-cli -p 26379 SENTINEL masters
  ```

### Post-Deployment Verification

#### Service Health
- [ ] All containers running
  ```bash
  docker compose -f docker-compose.prod.yml ps
  ```
- [ ] All health checks passing
  ```bash
  docker ps --format "table {{.Names}}\t{{.Status}}"
  ```
- [ ] No error logs in any service
  ```bash
  docker compose -f docker-compose.prod.yml logs --tail=50
  ```

#### Connectivity Tests
- [ ] HTTP redirects to HTTPS
  ```bash
  curl -I http://observatory.yourdomain.com
  ```
- [ ] HTTPS working
  ```bash
  curl -I https://observatory.yourdomain.com
  ```
- [ ] API endpoint accessible
  ```bash
  curl https://api.observatory.yourdomain.com/health
  ```
- [ ] WebSocket connections working (if applicable)
- [ ] Rate limiting working
  ```bash
  for i in {1..20}; do curl -I https://api.observatory.yourdomain.com/health; done
  ```

#### SSL/TLS Validation
- [ ] Certificate valid and trusted
- [ ] Certificate chain complete
- [ ] HSTS header present
  ```bash
  curl -I https://observatory.yourdomain.com | grep -i strict
  ```
- [ ] Security headers present
  ```bash
  curl -I https://observatory.yourdomain.com
  ```
- [ ] SSL Labs test passed (A+ rating)
  - Test at: https://www.ssllabs.com/ssltest/
- [ ] TLS 1.2+ only (no TLS 1.0/1.1)
- [ ] Strong cipher suites configured

#### Database Verification
- [ ] PostgreSQL responding
- [ ] TimescaleDB extension active
- [ ] Connection pooling working
- [ ] Query performance acceptable
- [ ] Hypertables created
  ```bash
  docker exec llm-observatory-db-primary psql -U postgres -d llm_observatory -c "SELECT * FROM timescaledb_information.hypertables;"
  ```
- [ ] Indexes created
- [ ] Database size reasonable
  ```bash
  docker exec llm-observatory-db-primary psql -U postgres -c "SELECT pg_size_pretty(pg_database_size('llm_observatory'));"
  ```
- [ ] Replication lag acceptable (if using replica)
  ```bash
  docker exec llm-observatory-db-primary psql -U postgres -c "SELECT * FROM pg_stat_replication;"
  ```

#### Cache Verification
- [ ] Redis responding
- [ ] Cache keys being set
  ```bash
  docker exec llm-observatory-redis-master redis-cli -a "$(cat secrets/redis_password.txt)" DBSIZE
  ```
- [ ] Cache hit rate acceptable
  ```bash
  docker exec llm-observatory-redis-master redis-cli -a "$(cat secrets/redis_password.txt)" INFO stats
  ```
- [ ] Memory usage reasonable
- [ ] Persistence enabled (AOF or RDB)
- [ ] Sentinel monitoring (if HA enabled)

#### Monitoring Setup
- [ ] Grafana accessible
- [ ] Grafana login working
- [ ] Datasource connected
- [ ] Dashboards loaded
- [ ] Metrics flowing
  - [ ] System metrics (CPU, memory, disk)
  - [ ] Application metrics
  - [ ] Database metrics
  - [ ] Cache metrics
- [ ] Alerts configured
  - [ ] High CPU alert
  - [ ] High memory alert
  - [ ] Disk space alert
  - [ ] Database connection alert
  - [ ] API error rate alert
- [ ] Alert notifications working
  - [ ] Test alert sent
  - [ ] Email received

#### Backup Verification
- [ ] Run manual backup
  ```bash
  docker compose -f docker-compose.prod.yml --profile backup run --rm backup
  ```
- [ ] Backup file created locally
  ```bash
  ls -lh /var/lib/llm-observatory/backups/
  ```
- [ ] Backup uploaded to S3
  ```bash
  aws s3 ls s3://llm-observatory-backups/production/backups/
  ```
- [ ] Backup encrypted
- [ ] Backup integrity verified
- [ ] WAL archiving working
  ```bash
  docker exec llm-observatory-db-primary ls -lh /var/lib/postgresql/wal_archive/
  ```
- [ ] Restore procedure tested (in staging)
- [ ] Backup schedule configured (cron)
- [ ] Backup monitoring/alerting configured

#### Performance Testing
- [ ] API response time acceptable (<100ms for /health)
  ```bash
  time curl https://api.observatory.yourdomain.com/health
  ```
- [ ] Database query performance acceptable
- [ ] Cache response time acceptable
- [ ] Grafana dashboard loading time acceptable
- [ ] WebSocket latency acceptable (if applicable)
- [ ] Load testing performed (optional but recommended)
  ```bash
  # Using Apache Bench
  ab -n 1000 -c 10 https://api.observatory.yourdomain.com/health
  ```

#### Security Validation
- [ ] All default passwords changed
- [ ] Strong passwords in use
- [ ] Secrets not in logs
  ```bash
  docker compose -f docker-compose.prod.yml logs | grep -i password
  ```
- [ ] Services running as non-root
  ```bash
  docker compose -f docker-compose.prod.yml exec api-server whoami
  ```
- [ ] Read-only filesystems where configured
- [ ] Unnecessary capabilities dropped
- [ ] Internal networks isolated
- [ ] Security scanning performed
  ```bash
  docker scan llm-observatory-api
  ```
- [ ] Vulnerability assessment completed
- [ ] Penetration testing performed (optional)

## Post-Deployment Tasks

### Documentation
- [ ] Deployment documented
  - [ ] Date and time
  - [ ] Version deployed
  - [ ] Configuration changes
  - [ ] Issues encountered
  - [ ] Resolution steps
- [ ] Runbook updated
- [ ] Architecture diagram updated
- [ ] Access credentials documented (securely)
- [ ] Oncall procedures updated
- [ ] Escalation paths documented

### Team Communication
- [ ] Team notified of deployment
- [ ] Deployment status communicated
- [ ] Known issues communicated
- [ ] Monitoring dashboard shared
- [ ] Oncall person notified
- [ ] Stakeholders updated

### Monitoring Setup
- [ ] Alert rules reviewed
- [ ] Notification channels tested
- [ ] Dashboard access granted to team
- [ ] SLO/SLA targets defined
- [ ] Incident response procedures reviewed
- [ ] Oncall rotation configured

### Training
- [ ] Team trained on new deployment
- [ ] Access granted to relevant team members
- [ ] Runbook walkthrough completed
- [ ] Troubleshooting guide reviewed
- [ ] Escalation procedures practiced

### Compliance
- [ ] Security audit completed
- [ ] Compliance requirements verified (GDPR, HIPAA, etc.)
- [ ] Data retention policies applied
- [ ] Privacy policy updated (if needed)
- [ ] Terms of service updated (if needed)
- [ ] Legal review completed (if required)

## Ongoing Maintenance Tasks

### Daily
- [ ] Check service health
- [ ] Review error logs
- [ ] Monitor disk space
- [ ] Check backup completion
- [ ] Review security logs
- [ ] Check performance metrics

### Weekly
- [ ] Review monitoring dashboards
- [ ] Analyze slow queries
- [ ] Check database statistics
- [ ] Review cache hit rates
- [ ] Analyze API usage patterns
- [ ] Check SSL certificate expiry
- [ ] Review security advisories

### Monthly
- [ ] Perform database maintenance
  - [ ] VACUUM ANALYZE
  - [ ] REINDEX
  - [ ] Check bloat
- [ ] Review resource usage trends
- [ ] Update dependencies
- [ ] Review and update documentation
- [ ] Test backup restore procedure
- [ ] Review and update secrets
- [ ] Capacity planning review
- [ ] Security patch review
- [ ] Cost optimization review

### Quarterly
- [ ] Disaster recovery drill
- [ ] Full security audit
- [ ] Performance tuning
- [ ] Architecture review
- [ ] Scalability assessment
- [ ] Technology stack review
- [ ] Team training refresh

## Rollback Procedure

If deployment fails, follow these steps:

### Immediate Rollback
- [ ] Stop all services
  ```bash
  docker compose -f docker-compose.prod.yml down
  ```
- [ ] Document failure reason
- [ ] Restore from last known good backup
  ```bash
  docker exec llm-observatory-db-primary pg_restore -U postgres -d llm_observatory -c /backups/last_good_backup.dump
  ```
- [ ] Start services with previous configuration
- [ ] Verify system operational
- [ ] Notify team of rollback
- [ ] Schedule post-mortem

### Post-Rollback
- [ ] Analyze failure
- [ ] Identify root cause
- [ ] Document lessons learned
- [ ] Update deployment procedure
- [ ] Plan remediation
- [ ] Schedule retry deployment

## Emergency Contacts

Document emergency contacts:

- **Technical Lead**: Name, Phone, Email
- **DevOps Lead**: Name, Phone, Email
- **Database Admin**: Name, Phone, Email
- **Security Team**: Name, Phone, Email
- **Oncall Engineer**: Name, Phone, Email
- **Escalation Manager**: Name, Phone, Email

## Sign-Off

### Pre-Deployment Sign-Off
- [ ] Technical Lead approval: ________________ Date: ________
- [ ] DevOps Lead approval: __________________ Date: ________
- [ ] Security approval: _____________________ Date: ________

### Post-Deployment Sign-Off
- [ ] Deployment verified by: ________________ Date: ________
- [ ] Monitoring confirmed by: _______________ Date: ________
- [ ] Security validated by: _________________ Date: ________

### Production Ready
- [ ] System ready for production traffic
- [ ] All checklist items completed
- [ ] Monitoring in place
- [ ] Backup verified
- [ ] Team trained
- [ ] Documentation complete

**Deployment Date**: _______________
**Deployed By**: ___________________
**Version**: _______________________
**Status**: ________________________

---

**Note**: This checklist should be customized based on your organization's specific requirements, compliance needs, and operational procedures.
