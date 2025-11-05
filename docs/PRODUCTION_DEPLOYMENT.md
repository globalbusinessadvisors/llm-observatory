# Production Deployment Guide

This guide provides comprehensive instructions for deploying LLM Observatory in a production environment with high availability, security hardening, and operational best practices.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Infrastructure Requirements](#infrastructure-requirements)
- [Pre-Deployment Setup](#pre-deployment-setup)
- [Security Hardening](#security-hardening)
- [Secrets Management](#secrets-management)
- [SSL/TLS Configuration](#ssltls-configuration)
- [Deployment](#deployment)
- [Post-Deployment Verification](#post-deployment-verification)
- [Monitoring and Alerting](#monitoring-and-alerting)
- [Scaling](#scaling)
- [Backup and Recovery](#backup-and-recovery)
- [Maintenance](#maintenance)
- [Troubleshooting](#troubleshooting)

## Overview

The production deployment consists of:

- **TimescaleDB Primary**: Main database with WAL archiving
- **TimescaleDB Replica**: Read replica for query load balancing
- **Redis Master**: Primary cache with persistence
- **Redis Sentinel**: Automatic failover for Redis
- **API Server**: Multiple replicas for high availability
- **Collector Service**: OpenTelemetry data collection
- **Grafana**: Visualization and dashboards
- **Nginx**: Reverse proxy with SSL/TLS termination

### Architecture Diagram

```
                         ┌──────────────┐
                         │   Internet   │
                         └──────┬───────┘
                                │
                                │ HTTPS (443)
                                │
                       ┌────────▼────────┐
                       │  Nginx Proxy    │
                       │  (TLS, HSTS)    │
                       └───┬──────────┬──┘
                           │          │
              ┌────────────┘          └─────────────┐
              │                                     │
              │ HTTP                                │ HTTP
              │                                     │
      ┌───────▼────────┐                   ┌───────▼────────┐
      │  API Server 1  │                   │  API Server 2  │
      │  (Replica 1)   │                   │  (Replica 2)   │
      └───┬────────────┘                   └────────┬───────┘
          │                                         │
          │                                         │
          └───────────────┬─────────────────────────┘
                          │
              ┌───────────┴──────────┐
              │                      │
      ┌───────▼────────┐    ┌───────▼────────┐
      │  TimescaleDB   │    │  Redis Master  │
      │    Primary     │◄───┤  + Sentinel    │
      │                │    │                │
      └───┬────────────┘    └────────────────┘
          │
          │ Replication
          │
      ┌───▼────────────┐
      │  TimescaleDB   │
      │    Replica     │
      │                │
      └────────────────┘
```

## Prerequisites

### System Requirements

**Minimum Production Server Specs:**
- **CPU**: 8 cores (16 recommended)
- **RAM**: 16GB (32GB recommended)
- **Storage**:
  - 100GB SSD for OS and application
  - 500GB+ SSD/NVMe for database (depends on data retention)
  - 100GB for backups (local staging before S3 upload)
- **Network**: 1Gbps+ network interface

**Operating System:**
- Ubuntu 22.04 LTS or 24.04 LTS (recommended)
- Debian 12
- RHEL 9 / Rocky Linux 9
- Amazon Linux 2023

### Software Requirements

```bash
# Docker and Docker Compose
docker --version  # >= 24.0
docker compose version  # >= 2.20

# Optional but recommended
git --version  # >= 2.40
openssl version  # >= 3.0
```

### Network Requirements

**Required Ports:**
- `443/tcp`: HTTPS (public)
- `80/tcp`: HTTP (redirect to HTTPS)

**Optional Monitoring Ports (internal only):**
- `5432/tcp`: PostgreSQL (database admin)
- `6379/tcp`: Redis (cache admin)
- `3000/tcp`: Grafana (dashboards)
- `9090/tcp`: Prometheus metrics
- `4317/tcp`: OTLP gRPC
- `4318/tcp`: OTLP HTTP

### DNS Configuration

Ensure DNS records are configured:

```
observatory.yourdomain.com      A/AAAA    <server-ip>
api.observatory.yourdomain.com  A/AAAA    <server-ip>
*.observatory.yourdomain.com    A/AAAA    <server-ip> (optional wildcard)
```

### External Services

**Required:**
- Domain name with SSL/TLS certificate
- SMTP server for alerts (SendGrid, SES, etc.)

**Recommended:**
- S3-compatible storage for backups (AWS S3, MinIO, Backblaze B2)
- Secret management service (AWS Secrets Manager, HashiCorp Vault)
- Log aggregation (CloudWatch, Datadog, ELK)
- Error tracking (Sentry)
- APM/Distributed tracing (Jaeger, Honeycomb)

## Infrastructure Requirements

### Cloud Provider Setup

#### AWS

```bash
# Create VPC
aws ec2 create-vpc --cidr-block 10.0.0.0/16

# Create subnets
aws ec2 create-subnet --vpc-id <vpc-id> --cidr-block 10.0.1.0/24 --availability-zone us-east-1a
aws ec2 create-subnet --vpc-id <vpc-id> --cidr-block 10.0.2.0/24 --availability-zone us-east-1b

# Create security group
aws ec2 create-security-group \
  --group-name llm-observatory-prod \
  --description "LLM Observatory Production" \
  --vpc-id <vpc-id>

# Configure security group rules
aws ec2 authorize-security-group-ingress \
  --group-id <sg-id> \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
  --group-id <sg-id> \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0

# Create EC2 instance
aws ec2 run-instances \
  --image-id ami-xxxxxxxxx \
  --instance-type c5.2xlarge \
  --key-name your-key \
  --security-group-ids <sg-id> \
  --subnet-id <subnet-id> \
  --block-device-mappings '[
    {
      "DeviceName": "/dev/sda1",
      "Ebs": {
        "VolumeSize": 100,
        "VolumeType": "gp3",
        "Iops": 3000,
        "Throughput": 125
      }
    },
    {
      "DeviceName": "/dev/sdb",
      "Ebs": {
        "VolumeSize": 500,
        "VolumeType": "gp3",
        "Iops": 16000,
        "Throughput": 1000
      }
    }
  ]'

# Create S3 buckets for backups
aws s3 mb s3://llm-observatory-backups
aws s3 mb s3://llm-observatory-wal

# Enable S3 bucket versioning
aws s3api put-bucket-versioning \
  --bucket llm-observatory-backups \
  --versioning-configuration Status=Enabled

# Create IAM role for EC2 instance
aws iam create-role \
  --role-name llm-observatory-ec2 \
  --assume-role-policy-document file://trust-policy.json

# Attach policies for S3 access
aws iam attach-role-policy \
  --role-name llm-observatory-ec2 \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess

# Create Secrets Manager secrets
aws secretsmanager create-secret \
  --name llm-observatory/prod/db-password \
  --secret-string "$(openssl rand -base64 32)"
```

#### GCP

```bash
# Create VPC
gcloud compute networks create llm-observatory \
  --subnet-mode=custom

# Create subnet
gcloud compute networks subnets create llm-observatory-subnet \
  --network=llm-observatory \
  --region=us-central1 \
  --range=10.0.0.0/24

# Create firewall rules
gcloud compute firewall-rules create llm-observatory-https \
  --network=llm-observatory \
  --allow=tcp:443,tcp:80 \
  --source-ranges=0.0.0.0/0

# Create VM instance
gcloud compute instances create llm-observatory-prod \
  --machine-type=n2-standard-8 \
  --zone=us-central1-a \
  --network=llm-observatory \
  --subnet=llm-observatory-subnet \
  --boot-disk-size=100GB \
  --boot-disk-type=pd-ssd \
  --create-disk=size=500GB,type=pd-ssd \
  --tags=llm-observatory

# Create GCS buckets
gsutil mb gs://llm-observatory-backups
gsutil mb gs://llm-observatory-wal

# Enable versioning
gsutil versioning set on gs://llm-observatory-backups

# Create secrets in Secret Manager
echo -n "$(openssl rand -base64 32)" | \
  gcloud secrets create db-password --data-file=-
```

### Bare Metal / On-Premises

**Server Configuration:**

1. **Install Operating System**: Ubuntu 22.04 LTS
2. **Configure RAID**: RAID 10 for database volumes
3. **Mount Data Volumes**:

```bash
# Create data directory structure
sudo mkdir -p /var/lib/llm-observatory/{timescaledb-primary,timescaledb-replica,redis-master,grafana,backups,wal_archive,nginx-logs}

# Set proper ownership
sudo chown -R 1000:1000 /var/lib/llm-observatory

# Mount dedicated volume for database
sudo mount /dev/sdb1 /var/lib/llm-observatory/timescaledb-primary

# Add to /etc/fstab for persistence
echo "/dev/sdb1 /var/lib/llm-observatory/timescaledb-primary ext4 defaults,noatime 0 2" | sudo tee -a /etc/fstab
```

4. **Configure Network**:

```bash
# Configure static IP
sudo nano /etc/netplan/01-netcfg.yaml
```

```yaml
network:
  version: 2
  ethernets:
    eth0:
      addresses:
        - 192.168.1.100/24
      gateway4: 192.168.1.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
```

```bash
sudo netplan apply
```

5. **Configure Firewall**:

```bash
# UFW
sudo ufw allow 443/tcp
sudo ufw allow 80/tcp
sudo ufw enable

# iptables
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables-save | sudo tee /etc/iptables/rules.v4
```

## Pre-Deployment Setup

### 1. Server Preparation

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  ufw \
  fail2ban \
  unattended-upgrades \
  git \
  htop \
  iotop \
  ncdu

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Verify installations
docker --version
docker compose version

# Log out and back in for group membership to take effect
```

### 2. System Optimization

```bash
# Increase file descriptor limits
sudo tee -a /etc/security/limits.conf <<EOF
* soft nofile 65536
* hard nofile 65536
* soft nproc 32768
* hard nproc 32768
EOF

# Kernel optimization for database and network
sudo tee -a /etc/sysctl.conf <<EOF
# Network optimization
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# Memory optimization
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
vm.overcommit_memory = 1

# PostgreSQL specific
kernel.shmmax = 17179869184
kernel.shmall = 4194304
kernel.sem = 250 32000 100 128

# File system
fs.file-max = 2097152
EOF

# Apply settings
sudo sysctl -p

# Disable transparent huge pages (THP) for PostgreSQL
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/enabled
echo never | sudo tee /sys/kernel/mm/transparent_hugepage/defrag

# Make THP settings persistent
sudo tee -a /etc/rc.local <<EOF
#!/bin/bash
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
exit 0
EOF
sudo chmod +x /etc/rc.local
```

### 3. Create Directory Structure

```bash
# Clone repository
cd /opt
sudo git clone https://github.com/llm-observatory/llm-observatory.git
sudo chown -R $USER:$USER llm-observatory
cd llm-observatory

# Create data directories
sudo mkdir -p /var/lib/llm-observatory/{timescaledb-primary,timescaledb-replica,redis-master,grafana,backups,wal_archive,nginx-logs}
sudo chown -R 1000:1000 /var/lib/llm-observatory

# Create secrets directory
mkdir -p secrets
chmod 700 secrets

# Create Docker configuration directories
mkdir -p docker/{certs/{postgres,redis,grafana,api,nginx},nginx/conf.d,grafana/{dashboards,datasources,alerting},backup,init}
```

## Security Hardening

### 1. Generate Secrets

```bash
# Generate strong random secrets
cd /opt/llm-observatory

# Database credentials
openssl rand -base64 32 > secrets/db_password.txt
openssl rand -base64 32 > secrets/db_app_password.txt
openssl rand -base64 32 > secrets/db_readonly_password.txt
openssl rand -base64 32 > secrets/db_replication_password.txt
echo "postgres" > secrets/db_user.txt

# Redis credentials
openssl rand -base64 32 > secrets/redis_password.txt

# Grafana credentials
echo "admin" > secrets/grafana_admin_user.txt
openssl rand -base64 32 > secrets/grafana_admin_password.txt
openssl rand -hex 32 > secrets/grafana_secret_key.txt

# Application secrets
openssl rand -hex 32 > secrets/secret_key.txt
openssl rand -hex 32 > secrets/jwt_secret.txt

# Backup encryption
openssl rand -hex 32 > secrets/backup_encryption_key.txt

# SMTP password
echo "your-smtp-password" > secrets/smtp_password.txt

# AWS credentials (if not using IAM roles)
echo "your-aws-access-key" > secrets/aws_access_key_id.txt
echo "your-aws-secret-key" > secrets/aws_secret_access_key.txt

# Generate database connection strings
DB_USER=$(cat secrets/db_user.txt)
DB_PASSWORD=$(cat secrets/db_password.txt)
echo "postgresql://${DB_USER}:${DB_PASSWORD}@timescaledb-primary:5432/llm_observatory" > secrets/database_url.txt

REDIS_PASSWORD=$(cat secrets/redis_password.txt)
echo "redis://:${REDIS_PASSWORD}@redis-master:6379/0" > secrets/redis_url.txt

# Secure permissions
chmod 600 secrets/*.txt
```

### 2. SSL/TLS Certificate Generation

#### Option A: Let's Encrypt (Recommended for Public Domains)

```bash
# Install certbot
sudo apt install -y certbot

# Obtain certificate
sudo certbot certonly --standalone \
  -d observatory.yourdomain.com \
  -d api.observatory.yourdomain.com \
  --email admin@yourdomain.com \
  --agree-tos \
  --no-eff-email

# Copy certificates to Docker volumes
sudo cp /etc/letsencrypt/live/observatory.yourdomain.com/fullchain.pem docker/certs/nginx/server.crt
sudo cp /etc/letsencrypt/live/observatory.yourdomain.com/privkey.pem docker/certs/nginx/server.key
sudo cp /etc/letsencrypt/live/observatory.yourdomain.com/chain.pem docker/certs/nginx/ca.crt

# Setup auto-renewal
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Post-renewal hook to copy certificates
sudo tee /etc/letsencrypt/renewal-hooks/post/copy-certs.sh <<EOF
#!/bin/bash
cp /etc/letsencrypt/live/observatory.yourdomain.com/fullchain.pem /opt/llm-observatory/docker/certs/nginx/server.crt
cp /etc/letsencrypt/live/observatory.yourdomain.com/privkey.pem /opt/llm-observatory/docker/certs/nginx/server.key
cp /etc/letsencrypt/live/observatory.yourdomain.com/chain.pem /opt/llm-observatory/docker/certs/nginx/ca.crt
docker exec llm-observatory-nginx nginx -s reload
EOF
sudo chmod +x /etc/letsencrypt/renewal-hooks/post/copy-certs.sh
```

#### Option B: Self-Signed Certificates (Testing/Internal Use Only)

```bash
# Create CA certificate
openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
  -keyout docker/certs/ca.key \
  -out docker/certs/ca.crt \
  -subj "/CN=LLM Observatory CA" \
  -extensions v3_ca

# Generate certificates for each service
for service in postgres redis grafana api nginx; do
  # Generate private key
  openssl genrsa -out docker/certs/${service}/${service}.key 4096

  # Create CSR
  openssl req -new \
    -key docker/certs/${service}/${service}.key \
    -out docker/certs/${service}/${service}.csr \
    -subj "/CN=${service}.llm-observatory.local"

  # Sign certificate with CA
  openssl x509 -req \
    -in docker/certs/${service}/${service}.csr \
    -CA docker/certs/ca.crt \
    -CAkey docker/certs/ca.key \
    -CAcreateserial \
    -out docker/certs/${service}/${service}.crt \
    -days 365 \
    -sha256

  # Copy CA cert
  cp docker/certs/ca.crt docker/certs/${service}/ca.crt

  # Set permissions
  chmod 644 docker/certs/${service}/${service}.crt
  chmod 600 docker/certs/${service}/${service}.key
done
```

### 3. Configure Firewall

```bash
# Configure UFW
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# Rate limiting for SSH
sudo ufw limit ssh/tcp

# Configure fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo nano /etc/fail2ban/jail.local
```

Add to `/etc/fail2ban/jail.local`:

```ini
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/lib/llm-observatory/nginx-logs/error.log
maxretry = 10
bantime = 600
```

```bash
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

## Secrets Management

### Option 1: AWS Secrets Manager (Recommended)

```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS CLI
aws configure

# Create secrets
aws secretsmanager create-secret \
  --name llm-observatory/prod/db-password \
  --secret-string "$(cat secrets/db_password.txt)"

aws secretsmanager create-secret \
  --name llm-observatory/prod/redis-password \
  --secret-string "$(cat secrets/redis_password.txt)"

# Retrieve secrets in deployment script
aws secretsmanager get-secret-value \
  --secret-id llm-observatory/prod/db-password \
  --query SecretString \
  --output text > secrets/db_password.txt
```

### Option 2: HashiCorp Vault

```bash
# Install Vault
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault

# Start Vault server
vault server -dev

# Set Vault address
export VAULT_ADDR='http://127.0.0.1:8200'

# Store secrets
vault kv put secret/llm-observatory/db password="$(cat secrets/db_password.txt)"
vault kv put secret/llm-observatory/redis password="$(cat secrets/redis_password.txt)"

# Retrieve secrets
vault kv get -field=password secret/llm-observatory/db > secrets/db_password.txt
```

### Option 3: Docker Secrets (Development/Testing)

Already configured in `docker-compose.prod.yml`.

## SSL/TLS Configuration

### Create Nginx SSL Configuration

```bash
cat > docker/nginx/ssl-params.conf <<'EOF'
# SSL/TLS Configuration for Production

# Protocols (TLS 1.2 and 1.3 only)
ssl_protocols TLSv1.2 TLSv1.3;

# Cipher suites (modern, secure ciphers)
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
ssl_prefer_server_ciphers off;

# SSL session configuration
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:50m;
ssl_session_tickets off;

# OCSP stapling
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;

# Security headers
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
add_header X-Frame-Options "DENY" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self'; frame-ancestors 'none';" always;

# Disable server tokens
server_tokens off;
EOF
```

### Create Nginx Main Configuration

```bash
cat > docker/nginx/nginx.prod.conf <<'EOF'
user nginx;
worker_processes auto;
worker_rlimit_nofile 65535;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for" '
                    'rt=$request_time uct="$upstream_connect_time" '
                    'uht="$upstream_header_time" urt="$upstream_response_time"';

    access_log /var/log/nginx/access.log main;

    # Performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 10M;
    client_body_buffer_size 128k;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/rss+xml font/truetype font/opentype application/vnd.ms-fontobject image/svg+xml;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=general:10m rate=100r/s;
    limit_conn_zone $binary_remote_addr zone=addr:10m;

    # Include site configurations
    include /etc/nginx/conf.d/*.conf;
}
EOF
```

### Create Site Configuration

```bash
cat > docker/nginx/conf.d/llm-observatory.conf <<'EOF'
# Upstream definitions
upstream api_backend {
    least_conn;
    server api-server:8080 max_fails=3 fail_timeout=30s;
    keepalive 32;
}

upstream grafana_backend {
    server grafana:3000;
}

# HTTP to HTTPS redirect
server {
    listen 80;
    listen [::]:80;
    server_name observatory.yourdomain.com api.observatory.yourdomain.com;

    # ACME challenge for Let's Encrypt
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# Main application (HTTPS)
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name observatory.yourdomain.com;

    # SSL certificates
    ssl_certificate /etc/nginx/certs/server.crt;
    ssl_certificate_key /etc/nginx/certs/server.key;
    ssl_trusted_certificate /etc/nginx/certs/ca.crt;

    # SSL configuration
    include /etc/nginx/ssl-params.conf;

    # Logging
    access_log /var/log/nginx/observatory-access.log main;
    error_log /var/log/nginx/observatory-error.log warn;

    # Root location
    location / {
        proxy_pass http://grafana_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Health check
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}

# API server (HTTPS)
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name api.observatory.yourdomain.com;

    # SSL certificates
    ssl_certificate /etc/nginx/certs/server.crt;
    ssl_certificate_key /etc/nginx/certs/server.key;
    ssl_trusted_certificate /etc/nginx/certs/ca.crt;

    # SSL configuration
    include /etc/nginx/ssl-params.conf;

    # Logging
    access_log /var/log/nginx/api-access.log main;
    error_log /var/log/nginx/api-error.log warn;

    # Rate limiting
    limit_req zone=api burst=20 nodelay;
    limit_conn addr 10;

    # API endpoints
    location / {
        proxy_pass http://api_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_http_version 1.1;
        proxy_set_header Connection "";

        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;

        # Buffering
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }

    # Metrics endpoint (restrict access)
    location /metrics {
        deny all;
        return 403;
    }

    # Health check
    location /health {
        access_log off;
        proxy_pass http://api_backend/health;
    }
}
EOF

# Replace domain placeholders
sed -i 's/observatory.yourdomain.com/'"$YOUR_DOMAIN"'/g' docker/nginx/conf.d/llm-observatory.conf
sed -i 's/api.observatory.yourdomain.com/api.'"$YOUR_DOMAIN"'/g' docker/nginx/conf.d/llm-observatory.conf
```

## Deployment

### 1. Configure Environment

```bash
cd /opt/llm-observatory

# Copy production environment template
cp .env.production.example .env.production

# Edit configuration
nano .env.production
```

Update these critical values:
- `GRAFANA_ROOT_URL` and `GRAFANA_DOMAIN`
- `CORS_ORIGINS`
- `S3_BACKUP_BUCKET`, `AWS_REGION`
- `NOTIFICATION_EMAIL`
- `SMTP_*` settings
- `DATA_DIR` (if different from default)

### 2. Pre-Flight Checks

```bash
# Verify secrets exist
ls -lh secrets/

# Verify certificates exist
ls -lh docker/certs/*/

# Verify data directories
ls -ld /var/lib/llm-observatory/*/

# Check available resources
df -h /var/lib/llm-observatory
free -h
nproc

# Test Docker
docker run --rm hello-world

# Validate docker-compose configuration
docker compose -f docker-compose.prod.yml config

# Check for port conflicts
sudo netstat -tlnp | grep -E ':(80|443|5432|6379|3000|8080)'
```

### 3. Initial Deployment

```bash
# Load environment
export $(cat .env.production | xargs)

# Pull images
docker compose -f docker-compose.prod.yml pull

# Build custom images (if any)
docker compose -f docker-compose.prod.yml build --no-cache

# Start infrastructure services first
docker compose -f docker-compose.prod.yml up -d timescaledb-primary redis-master

# Wait for services to be healthy
until docker exec llm-observatory-db-primary pg_isready -U postgres; do
  echo "Waiting for database..."
  sleep 5
done

# Run database migrations
docker compose -f docker-compose.prod.yml run --rm api-server \
  /app/bin/migrate up

# Start remaining services
docker compose -f docker-compose.prod.yml up -d

# Check status
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs -f
```

### 4. Start with High Availability

To enable read replicas and Redis Sentinel:

```bash
docker compose -f docker-compose.prod.yml --profile with-replica --profile with-ha up -d
```

## Post-Deployment Verification

### 1. Service Health Checks

```bash
# Check all containers are running
docker compose -f docker-compose.prod.yml ps

# Check health status
docker ps --format "table {{.Names}}\t{{.Status}}"

# Test database connectivity
docker exec llm-observatory-db-primary psql -U postgres -d llm_observatory -c "SELECT version();"

# Test Redis connectivity
docker exec llm-observatory-redis-master redis-cli -a "$(cat secrets/redis_password.txt)" PING

# Test API endpoint
curl -k https://api.observatory.yourdomain.com/health

# Test Grafana
curl -k https://observatory.yourdomain.com/api/health
```

### 2. Verify SSL/TLS

```bash
# Check SSL certificate
openssl s_client -connect observatory.yourdomain.com:443 -servername observatory.yourdomain.com < /dev/null

# Test SSL configuration
curl -vI https://observatory.yourdomain.com

# SSL Labs test (online)
# https://www.ssllabs.com/ssltest/analyze.html?d=observatory.yourdomain.com
```

### 3. Database Initialization

```bash
# Verify TimescaleDB extension
docker exec llm-observatory-db-primary psql -U postgres -d llm_observatory -c "\dx"

# Check hypertables
docker exec llm-observatory-db-primary psql -U postgres -d llm_observatory -c "SELECT * FROM timescaledb_information.hypertables;"

# Verify users and permissions
docker exec llm-observatory-db-primary psql -U postgres -c "\du"
```

### 4. Monitoring Setup

```bash
# Access Grafana
open https://observatory.yourdomain.com

# Login with credentials from secrets
GRAFANA_USER=$(cat secrets/grafana_admin_user.txt)
GRAFANA_PASS=$(cat secrets/grafana_admin_password.txt)

# Configure datasource via API
curl -X POST \
  -H "Content-Type: application/json" \
  -u "${GRAFANA_USER}:${GRAFANA_PASS}" \
  https://observatory.yourdomain.com/api/datasources \
  -d @docker/grafana/datasources/timescaledb.json
```

### 5. Test Backup System

```bash
# Run manual backup
docker compose -f docker-compose.prod.yml --profile backup run --rm backup

# Verify backup was created
ls -lh /var/lib/llm-observatory/backups/

# Verify S3 upload (if configured)
aws s3 ls s3://llm-observatory-backups/production/backups/
```

## Monitoring and Alerting

See [MONITORING.md](./MONITORING.md) for detailed monitoring configuration.

**Quick Setup:**

```bash
# Enable Prometheus metrics
docker compose -f docker/monitoring-stack.yml up -d

# Configure Grafana alerts
docker cp docker/grafana/alerting/*.yaml llm-observatory-grafana:/etc/grafana/provisioning/alerting/
docker compose -f docker-compose.prod.yml restart grafana
```

## Scaling

### Vertical Scaling

**Scale up database resources:**

Edit `.env.production`:

```bash
# For 32GB RAM server
DB_SHARED_BUFFERS=8GB
DB_WORK_MEM=128MB
DB_MAINTENANCE_WORK_MEM=1GB
DB_EFFECTIVE_CACHE_SIZE=24GB
```

Restart services:

```bash
docker compose -f docker-compose.prod.yml restart timescaledb-primary
```

### Horizontal Scaling

**Scale API servers:**

```bash
# Scale to 4 replicas
docker compose -f docker-compose.prod.yml up -d --scale api-server=4

# Verify
docker compose -f docker-compose.prod.yml ps api-server
```

**Enable read replicas:**

```bash
# Start with replica profile
docker compose -f docker-compose.prod.yml --profile with-replica up -d

# Configure application to use read replica for queries
# Edit application configuration to use timescaledb-replica:5432 for read operations
```

## Backup and Recovery

See [BACKUP_INFRASTRUCTURE.md](./BACKUP_INFRASTRUCTURE.md) for complete backup documentation.

**Quick Backup Commands:**

```bash
# Manual backup
docker compose -f docker-compose.prod.yml --profile backup run --rm backup

# Automated backups via cron
crontab -e
```

Add:

```cron
# Daily backup at 2 AM
0 2 * * * cd /opt/llm-observatory && docker compose -f docker-compose.prod.yml --profile backup run --rm backup >> /var/log/llm-obs-backup.log 2>&1

# Weekly full backup (Sunday 3 AM)
0 3 * * 0 cd /opt/llm-observatory && docker compose -f docker-compose.prod.yml --profile backup run --rm backup --full >> /var/log/llm-obs-backup.log 2>&1
```

**Restore from Backup:**

```bash
# Stop services
docker compose -f docker-compose.prod.yml stop api-server collector

# Restore database
docker exec llm-observatory-db-primary pg_restore \
  -U postgres \
  -d llm_observatory \
  -c \
  /backups/llm_observatory_20250105_020000.dump

# Start services
docker compose -f docker-compose.prod.yml start api-server collector
```

## Maintenance

### Rolling Updates

```bash
# Pull latest images
docker compose -f docker-compose.prod.yml pull

# Update services one at a time
docker compose -f docker-compose.prod.yml up -d --no-deps api-server

# Verify health
docker compose -f docker-compose.prod.yml ps api-server

# Update remaining services
docker compose -f docker-compose.prod.yml up -d
```

### Database Maintenance

```bash
# Vacuum and analyze
docker exec llm-observatory-db-primary psql -U postgres -d llm_observatory -c "VACUUM ANALYZE;"

# Reindex
docker exec llm-observatory-db-primary psql -U postgres -d llm_observatory -c "REINDEX DATABASE llm_observatory;"

# Check database size
docker exec llm-observatory-db-primary psql -U postgres -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) AS size FROM pg_database;"
```

### Log Rotation

Docker logs are automatically rotated based on configuration in `docker-compose.prod.yml`.

**Manual log management:**

```bash
# View log sizes
docker compose -f docker-compose.prod.yml ps -q | xargs -I {} docker inspect --format='{{.Name}} {{.LogPath}}' {} | xargs -I {} sh -c 'echo {}; du -h $(echo {} | awk "{print \$2}")'

# Truncate logs (if needed)
docker compose -f docker-compose.prod.yml ps -q | xargs -I {} sh -c 'truncate -s 0 $(docker inspect --format="{{.LogPath}}" {})'
```

## Troubleshooting

### Common Issues

**1. Database Connection Failed**

```bash
# Check database is running
docker ps -f name=timescaledb-primary

# Check logs
docker logs llm-observatory-db-primary

# Test connection
docker exec llm-observatory-db-primary pg_isready -U postgres

# Check network connectivity
docker network inspect llm-observatory-backend
```

**2. High Memory Usage**

```bash
# Check container memory usage
docker stats

# Check PostgreSQL settings
docker exec llm-observatory-db-primary psql -U postgres -c "SHOW shared_buffers; SHOW work_mem; SHOW effective_cache_size;"

# Reduce memory if needed (edit .env.production and restart)
```

**3. SSL Certificate Issues**

```bash
# Verify certificate files exist
ls -lh docker/certs/nginx/

# Check certificate validity
openssl x509 -in docker/certs/nginx/server.crt -text -noout

# Reload nginx
docker exec llm-observatory-nginx nginx -t
docker exec llm-observatory-nginx nginx -s reload
```

**4. API Rate Limiting**

```bash
# Check nginx rate limit zones
docker exec llm-observatory-nginx cat /var/log/nginx/error.log | grep "limiting requests"

# Adjust rate limits in docker/nginx/conf.d/llm-observatory.conf
```

### Debug Mode

```bash
# Enable debug logging
docker compose -f docker-compose.prod.yml stop api-server
docker compose -f docker-compose.prod.yml run --rm -e RUST_LOG=debug -e LOG_LEVEL=debug api-server

# View all logs
docker compose -f docker-compose.prod.yml logs -f --tail=100
```

### Performance Profiling

```bash
# PostgreSQL slow query log
docker exec llm-observatory-db-primary psql -U postgres -c "SELECT * FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10;"

# Connection pool stats
docker exec llm-observatory-db-primary psql -U postgres -c "SELECT * FROM pg_stat_activity;"

# Redis performance
docker exec llm-observatory-redis-master redis-cli -a "$(cat secrets/redis_password.txt)" INFO stats
```

## Security Checklist

- [ ] All default passwords changed
- [ ] Strong random secrets generated
- [ ] SSL/TLS certificates installed and valid
- [ ] Firewall configured (only 80/443 open)
- [ ] Fail2ban enabled and configured
- [ ] Docker secrets or external secret manager in use
- [ ] Database encrypted at rest (if required)
- [ ] Backups encrypted
- [ ] Audit logging enabled
- [ ] Security headers configured in Nginx
- [ ] HSTS enabled
- [ ] Rate limiting enabled
- [ ] CORS properly configured
- [ ] Non-root users for all containers
- [ ] Read-only filesystems where possible
- [ ] Capabilities dropped
- [ ] Regular security updates scheduled

## Support and Resources

- **Documentation**: https://docs.llm-observatory.io
- **GitHub**: https://github.com/llm-observatory/llm-observatory
- **Issues**: https://github.com/llm-observatory/llm-observatory/issues
- **Community**: https://discord.gg/llm-observatory

---

**Next Steps:**
- [Production Checklist](./PRODUCTION_CHECKLIST.md)
- [Secrets Management Guide](./SECRETS_MANAGEMENT.md)
- [Scaling Guide](./SCALING_GUIDE.md)
- [Operations Manual](./OPERATIONS_MANUAL.md)
