# Secrets Management Guide

Comprehensive guide for managing secrets, credentials, and sensitive configuration in LLM Observatory production deployments.

## Table of Contents

- [Overview](#overview)
- [Secret Types](#secret-types)
- [Security Best Practices](#security-best-practices)
- [Secret Generation](#secret-generation)
- [Storage Options](#storage-options)
- [Integration Methods](#integration-methods)
- [Rotation Procedures](#rotation-procedures)
- [Backup and Recovery](#backup-and-recovery)
- [Audit and Compliance](#audit-and-compliance)
- [Troubleshooting](#troubleshooting)

## Overview

LLM Observatory requires various secrets for secure operation:
- Database credentials
- API keys and tokens
- Encryption keys
- SSL/TLS certificates
- Third-party service credentials

**Security Principles:**
1. **Least Privilege**: Grant minimum necessary permissions
2. **Defense in Depth**: Multiple layers of security
3. **Separation of Duties**: No single person has all access
4. **Regular Rotation**: Periodic credential updates
5. **Audit Trail**: Log all secret access
6. **Encryption**: Encrypt secrets at rest and in transit

## Secret Types

### Critical Secrets (Tier 1)

**Database Credentials:**
- `DB_USER`: PostgreSQL superuser (postgres)
- `DB_PASSWORD`: PostgreSQL superuser password
- `DB_APP_PASSWORD`: Application database user password
- `DB_READONLY_PASSWORD`: Read-only user password
- `DB_REPLICATION_PASSWORD`: Replication user password

**Application Secrets:**
- `SECRET_KEY`: Application-wide encryption key
- `JWT_SECRET`: JWT token signing key
- `BACKUP_ENCRYPTION_KEY`: Backup file encryption key

**Redis Credentials:**
- `REDIS_PASSWORD`: Redis authentication password

**Impact of Compromise:** Complete system compromise, data breach

**Rotation Frequency:** Every 90 days or immediately if compromised

### Important Secrets (Tier 2)

**Admin Credentials:**
- `GRAFANA_ADMIN_USER`: Grafana admin username
- `GRAFANA_ADMIN_PASSWORD`: Grafana admin password
- `GRAFANA_SECRET_KEY`: Grafana session encryption key

**Cloud Services:**
- `AWS_ACCESS_KEY_ID`: AWS access key
- `AWS_SECRET_ACCESS_KEY`: AWS secret key
- `S3_KMS_KEY_ID`: S3 encryption key ID

**Email/SMTP:**
- `SMTP_PASSWORD`: SMTP authentication password

**Impact of Compromise:** Limited system access, potential data exposure

**Rotation Frequency:** Every 180 days

### Standard Secrets (Tier 3)

**API Keys (External Services):**
- `OPENAI_API_KEY`: OpenAI API key
- `ANTHROPIC_API_KEY`: Anthropic API key
- `SENTRY_DSN`: Sentry error tracking DSN

**Impact of Compromise:** Service-specific impact, potential cost

**Rotation Frequency:** Annually or per service policy

## Security Best Practices

### General Principles

1. **Never Commit Secrets to Version Control**
   ```bash
   # Add to .gitignore
   echo "secrets/" >> .gitignore
   echo ".env.production" >> .gitignore
   echo "*.key" >> .gitignore
   echo "*.pem" >> .gitignore
   ```

2. **Use Strong Random Generation**
   ```bash
   # Use cryptographically secure random generators
   openssl rand -base64 32  # For passwords
   openssl rand -hex 32     # For keys
   uuidgen                  # For UUIDs
   ```

3. **Encrypt Secrets at Rest**
   ```bash
   # Encrypt with GPG
   gpg --symmetric --cipher-algo AES256 secrets/db_password.txt

   # Encrypt with age
   age -p -o secrets/db_password.txt.age secrets/db_password.txt
   ```

4. **Limit Access**
   ```bash
   # Set restrictive permissions
   chmod 600 secrets/*.txt
   chmod 700 secrets/

   # Verify no world-readable secrets
   find secrets/ -type f -perm /o+r
   ```

5. **Use Separate Secrets per Environment**
   - Development: Weak passwords OK, local storage
   - Staging: Strong passwords, test secret management
   - Production: Maximum security, external secret manager

### Secret File Permissions

**Correct Permissions:**
```bash
# Secrets directory
drwx------  2 user user 4096 Jan  5 10:00 secrets/

# Secret files
-rw-------  1 user user   44 Jan  5 10:00 db_password.txt
-rw-------  1 user user   44 Jan  5 10:00 secret_key.txt
```

**Check and Fix Permissions:**
```bash
# Find world-readable files
find . -type f \( -perm -004 \) -ls

# Fix permissions
chmod 700 secrets/
chmod 600 secrets/*.txt
```

## Secret Generation

### Automated Generation Script

Create a script to generate all required secrets:

```bash
#!/bin/bash
# generate-secrets.sh - Generate all production secrets

set -e

SECRETS_DIR="secrets"
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

echo "Generating secrets..."

# Database credentials
echo "postgres" > "$SECRETS_DIR/db_user.txt"
openssl rand -base64 32 > "$SECRETS_DIR/db_password.txt"
openssl rand -base64 32 > "$SECRETS_DIR/db_app_password.txt"
openssl rand -base64 32 > "$SECRETS_DIR/db_readonly_password.txt"
openssl rand -base64 32 > "$SECRETS_DIR/db_replication_password.txt"

# Redis
openssl rand -base64 32 > "$SECRETS_DIR/redis_password.txt"

# Grafana
echo "admin" > "$SECRETS_DIR/grafana_admin_user.txt"
openssl rand -base64 32 > "$SECRETS_DIR/grafana_admin_password.txt"
openssl rand -hex 32 > "$SECRETS_DIR/grafana_secret_key.txt"

# Application secrets
openssl rand -hex 32 > "$SECRETS_DIR/secret_key.txt"
openssl rand -hex 32 > "$SECRETS_DIR/jwt_secret.txt"
openssl rand -hex 32 > "$SECRETS_DIR/backup_encryption_key.txt"

# Generate connection strings
DB_USER=$(cat "$SECRETS_DIR/db_user.txt")
DB_PASSWORD=$(cat "$SECRETS_DIR/db_password.txt")
echo "postgresql://${DB_USER}:${DB_PASSWORD}@timescaledb-primary:5432/llm_observatory" > "$SECRETS_DIR/database_url.txt"

REDIS_PASSWORD=$(cat "$SECRETS_DIR/redis_password.txt")
echo "redis://:${REDIS_PASSWORD}@redis-master:6379/0" > "$SECRETS_DIR/redis_url.txt"

# Set proper permissions
chmod 600 "$SECRETS_DIR"/*.txt

echo "Secrets generated successfully!"
echo "Review and update the following manually:"
echo "  - secrets/smtp_password.txt"
echo "  - secrets/aws_access_key_id.txt"
echo "  - secrets/aws_secret_access_key.txt"

# Create inventory
cat > "$SECRETS_DIR/INVENTORY.md" <<EOF
# Secrets Inventory

Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

## Database Secrets
- db_user.txt
- db_password.txt
- db_app_password.txt
- db_readonly_password.txt
- db_replication_password.txt
- database_url.txt

## Cache Secrets
- redis_password.txt
- redis_url.txt

## Application Secrets
- secret_key.txt
- jwt_secret.txt
- backup_encryption_key.txt

## Admin Credentials
- grafana_admin_user.txt
- grafana_admin_password.txt
- grafana_secret_key.txt

## External Services
- smtp_password.txt
- aws_access_key_id.txt
- aws_secret_access_key.txt

## Rotation Schedule
- Tier 1 secrets: Every 90 days
- Tier 2 secrets: Every 180 days
- Tier 3 secrets: Annually

Last Rotation: $(date -u +"%Y-%m-%d")
Next Rotation: $(date -u -d "+90 days" +"%Y-%m-%d")
EOF

chmod 600 "$SECRETS_DIR/INVENTORY.md"
```

Usage:
```bash
chmod +x generate-secrets.sh
./generate-secrets.sh
```

### Manual Generation

For manual generation:

```bash
# Database password (32 characters)
openssl rand -base64 32

# Application key (64 hex characters)
openssl rand -hex 32

# UUID (for identifiers)
uuidgen

# Alphanumeric (for API tokens)
LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32 ; echo
```

### Strength Requirements

**Passwords:**
- Minimum length: 32 characters
- Character set: Base64 (a-zA-Z0-9+/)
- Entropy: ~192 bits
- Generator: `openssl rand -base64 32`

**Keys:**
- Minimum length: 64 hex characters (32 bytes)
- Character set: Hexadecimal (0-9a-f)
- Entropy: ~256 bits
- Generator: `openssl rand -hex 32`

**API Tokens:**
- Format: Service-specific
- Minimum entropy: 128 bits
- Use service-provided generators when available

## Storage Options

### Option 1: Docker Secrets (Basic)

**Use Case:** Single-server deployments, development

**Pros:**
- Simple to implement
- No external dependencies
- Encrypted in Docker's internal database

**Cons:**
- Limited to single Docker host
- Basic access control
- No built-in rotation
- Not suitable for multi-server deployments

**Implementation:**

```yaml
# docker-compose.prod.yml
secrets:
  db_password:
    file: ./secrets/db_password.txt

services:
  timescaledb-primary:
    secrets:
      - db_password
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
```

**Access in Container:**
```bash
# Secret available at /run/secrets/
cat /run/secrets/db_password
```

### Option 2: AWS Secrets Manager (Recommended)

**Use Case:** AWS deployments, enterprise production

**Pros:**
- Fully managed service
- Automatic rotation support
- Fine-grained IAM access control
- Encryption with AWS KMS
- Audit logging with CloudTrail
- High availability

**Cons:**
- AWS vendor lock-in
- Additional cost ($0.40/secret/month + API calls)
- Requires IAM configuration

**Setup:**

```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure credentials
aws configure

# Create secrets
aws secretsmanager create-secret \
  --name llm-observatory/prod/db-password \
  --description "PostgreSQL admin password" \
  --secret-string "$(openssl rand -base64 32)" \
  --tags Key=Environment,Value=production Key=Service,Value=llm-observatory

aws secretsmanager create-secret \
  --name llm-observatory/prod/redis-password \
  --secret-string "$(openssl rand -base64 32)"

# Enable automatic rotation (Lambda required)
aws secretsmanager rotate-secret \
  --secret-id llm-observatory/prod/db-password \
  --rotation-lambda-arn arn:aws:lambda:us-east-1:123456789012:function:SecretsManagerRotation \
  --rotation-rules AutomaticallyAfterDays=90
```

**Retrieval Script:**

```bash
#!/bin/bash
# fetch-secrets-aws.sh

set -e

SECRETS_DIR="secrets"
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

# Fetch secrets from AWS Secrets Manager
fetch_secret() {
  local secret_name=$1
  local output_file=$2

  echo "Fetching $secret_name..."
  aws secretsmanager get-secret-value \
    --secret-id "$secret_name" \
    --query SecretString \
    --output text > "$SECRETS_DIR/$output_file"

  chmod 600 "$SECRETS_DIR/$output_file"
}

# Fetch all secrets
fetch_secret "llm-observatory/prod/db-password" "db_password.txt"
fetch_secret "llm-observatory/prod/redis-password" "redis_password.txt"
fetch_secret "llm-observatory/prod/secret-key" "secret_key.txt"
fetch_secret "llm-observatory/prod/jwt-secret" "jwt_secret.txt"
# ... add more as needed

echo "Secrets fetched successfully!"
```

**IAM Policy for EC2:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": [
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:llm-observatory/prod/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt"
      ],
      "Resource": [
        "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
      ]
    }
  ]
}
```

### Option 3: HashiCorp Vault (Enterprise)

**Use Case:** Multi-cloud, complex deployments, strict compliance

**Pros:**
- Vendor-agnostic
- Dynamic secrets
- Powerful policy engine
- Secret versioning
- Comprehensive audit logs
- Encryption as a service
- Active Directory integration

**Cons:**
- Complex setup and maintenance
- Requires dedicated infrastructure
- Steeper learning curve
- Self-hosted (or HCP Vault Cloud)

**Setup:**

```bash
# Install Vault
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault

# Start Vault server (production config)
sudo tee /etc/vault.d/vault.hcl <<EOF
storage "raft" {
  path    = "/opt/vault/data"
  node_id = "node1"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_cert_file = "/etc/vault.d/tls/vault.crt"
  tls_key_file  = "/etc/vault.d/tls/vault.key"
}

api_addr = "https://vault.yourdomain.com:8200"
cluster_addr = "https://vault.yourdomain.com:8201"
ui = true
EOF

sudo systemctl enable vault
sudo systemctl start vault

# Initialize Vault
vault operator init -key-shares=5 -key-threshold=3 > vault-keys.txt

# Unseal Vault (requires 3 of 5 keys)
vault operator unseal <key1>
vault operator unseal <key2>
vault operator unseal <key3>

# Login with root token
vault login <root_token>

# Enable KV secrets engine
vault secrets enable -path=llm-observatory kv-v2

# Store secrets
vault kv put llm-observatory/prod/database \
  password="$(openssl rand -base64 32)"

vault kv put llm-observatory/prod/redis \
  password="$(openssl rand -base64 32)"

# Create policy
vault policy write llm-observatory-prod - <<EOF
path "llm-observatory/data/prod/*" {
  capabilities = ["read", "list"]
}
EOF

# Create token for application
vault token create -policy=llm-observatory-prod -ttl=720h
```

**Retrieval Script:**

```bash
#!/bin/bash
# fetch-secrets-vault.sh

set -e

VAULT_ADDR="https://vault.yourdomain.com:8200"
VAULT_TOKEN="<app_token>"

SECRETS_DIR="secrets"
mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

# Fetch secret
fetch_secret() {
  local path=$1
  local field=$2
  local output_file=$3

  echo "Fetching $path ($field)..."
  vault kv get -field="$field" "llm-observatory/prod/$path" > "$SECRETS_DIR/$output_file"
  chmod 600 "$SECRETS_DIR/$output_file"
}

# Fetch all secrets
fetch_secret "database" "password" "db_password.txt"
fetch_secret "redis" "password" "redis_password.txt"
fetch_secret "application" "secret_key" "secret_key.txt"
fetch_secret "application" "jwt_secret" "jwt_secret.txt"

echo "Secrets fetched successfully!"
```

### Option 4: Google Secret Manager

**Use Case:** GCP deployments

```bash
# Enable Secret Manager API
gcloud services enable secretmanager.googleapis.com

# Create secrets
echo -n "$(openssl rand -base64 32)" | \
  gcloud secrets create db-password \
  --data-file=- \
  --replication-policy="automatic"

# Grant access to service account
gcloud secrets add-iam-policy-binding db-password \
  --member="serviceAccount:llm-obs@project.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# Retrieve secret
gcloud secrets versions access latest --secret="db-password" > secrets/db_password.txt
```

### Option 5: Azure Key Vault

**Use Case:** Azure deployments

```bash
# Create Key Vault
az keyvault create \
  --name llm-observatory-vault \
  --resource-group llm-observatory-prod \
  --location eastus

# Store secret
az keyvault secret set \
  --vault-name llm-observatory-vault \
  --name db-password \
  --value "$(openssl rand -base64 32)"

# Grant access to managed identity
az keyvault set-policy \
  --name llm-observatory-vault \
  --object-id <managed_identity_id> \
  --secret-permissions get list

# Retrieve secret
az keyvault secret show \
  --vault-name llm-observatory-vault \
  --name db-password \
  --query value -o tsv > secrets/db_password.txt
```

## Integration Methods

### Method 1: File-Based Secrets

**Use Docker Secrets or write to filesystem:**

```yaml
# docker-compose.prod.yml
services:
  api-server:
    environment:
      DATABASE_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
```

**Application reads from file:**

```rust
// Rust example
use std::fs;

fn read_secret(path: &str) -> Result<String, std::io::Error> {
    fs::read_to_string(path)?.trim().to_string()
}

let db_password = read_secret("/run/secrets/db_password")?;
```

### Method 2: Environment Variables

**Fetch secrets and inject as environment variables:**

```bash
# fetch-and-run.sh
#!/bin/bash

# Fetch secrets
./fetch-secrets-aws.sh

# Export as environment variables
export DB_PASSWORD=$(cat secrets/db_password.txt)
export REDIS_PASSWORD=$(cat secrets/redis_password.txt)

# Start services
docker compose -f docker-compose.prod.yml up -d
```

**Security Note:** Environment variables are less secure than files because they may be visible in process listings.

### Method 3: Direct API Integration

**Application fetches secrets directly:**

```rust
// Rust with AWS SDK
use aws_sdk_secretsmanager::Client;

async fn get_secret(client: &Client, secret_id: &str) -> String {
    let resp = client
        .get_secret_value()
        .secret_id(secret_id)
        .send()
        .await
        .unwrap();

    resp.secret_string().unwrap().to_string()
}

// Usage
let config = aws_config::load_from_env().await;
let client = Client::new(&config);
let db_password = get_secret(&client, "llm-observatory/prod/db-password").await;
```

**Pros:**
- Most secure (no secrets on disk)
- Dynamic secret updates
- Fine-grained access control

**Cons:**
- Application dependency on secret service
- Increased complexity
- Network latency

### Method 4: Init Container Pattern (Kubernetes)

```yaml
# For Kubernetes deployments
apiVersion: v1
kind: Pod
metadata:
  name: llm-observatory-api
spec:
  initContainers:
  - name: fetch-secrets
    image: amazon/aws-cli
    command:
      - sh
      - -c
      - |
        aws secretsmanager get-secret-value --secret-id llm-observatory/prod/db-password --query SecretString --output text > /secrets/db_password.txt
        chmod 600 /secrets/db_password.txt
    volumeMounts:
    - name: secrets
      mountPath: /secrets

  containers:
  - name: api-server
    image: llm-observatory-api:latest
    volumeMounts:
    - name: secrets
      mountPath: /run/secrets
      readOnly: true

  volumes:
  - name: secrets
    emptyDir:
      medium: Memory  # tmpfs, not persisted to disk
```

## Rotation Procedures

### Database Password Rotation

**Zero-Downtime Rotation:**

```bash
#!/bin/bash
# rotate-db-password.sh

set -e

OLD_PASSWORD=$(cat secrets/db_password.txt)
NEW_PASSWORD=$(openssl rand -base64 32)

# 1. Add new password as alternative authentication
docker exec llm-observatory-db-primary psql -U postgres -c \
  "ALTER USER postgres WITH PASSWORD '$NEW_PASSWORD';"

# 2. Update secret in secret manager
aws secretsmanager update-secret \
  --secret-id llm-observatory/prod/db-password \
  --secret-string "$NEW_PASSWORD"

# 3. Update local secret file
echo "$NEW_PASSWORD" > secrets/db_password.txt.new
chmod 600 secrets/db_password.txt.new

# 4. Update connection strings
DB_USER=$(cat secrets/db_user.txt)
echo "postgresql://${DB_USER}:${NEW_PASSWORD}@timescaledb-primary:5432/llm_observatory" > secrets/database_url.txt.new

# 5. Rolling restart of services (one at a time)
echo "Restarting services with new password..."

# Move new secrets into place
mv secrets/db_password.txt.new secrets/db_password.txt
mv secrets/database_url.txt.new secrets/database_url.txt

# Restart services one by one
for service in api-server collector; do
  echo "Restarting $service..."
  docker compose -f docker-compose.prod.yml up -d --no-deps --force-recreate $service

  # Wait for health check
  sleep 10

  # Verify service is healthy
  if ! docker ps --filter "name=$service" --filter "health=healthy" | grep -q "$service"; then
    echo "ERROR: $service failed health check"
    # Rollback
    echo "$OLD_PASSWORD" > secrets/db_password.txt
    docker compose -f docker-compose.prod.yml up -d --no-deps --force-recreate $service
    exit 1
  fi
done

echo "Database password rotated successfully!"

# Log rotation event
echo "$(date -u +"%Y-%m-%d %H:%M:%S UTC") - Database password rotated" >> secrets/rotation.log
```

### Application Secret Rotation

```bash
#!/bin/bash
# rotate-app-secrets.sh

set -e

NEW_SECRET_KEY=$(openssl rand -hex 32)
NEW_JWT_SECRET=$(openssl rand -hex 32)

# Update secrets
echo "$NEW_SECRET_KEY" > secrets/secret_key.txt
echo "$NEW_JWT_SECRET" > secrets/jwt_secret.txt
chmod 600 secrets/*.txt

# Update in secret manager
aws secretsmanager update-secret \
  --secret-id llm-observatory/prod/secret-key \
  --secret-string "$NEW_SECRET_KEY"

aws secretsmanager update-secret \
  --secret-id llm-observatory/prod/jwt-secret \
  --secret-string "$NEW_JWT_SECRET"

# Restart services
docker compose -f docker-compose.prod.yml restart api-server collector

echo "Application secrets rotated successfully!"
```

### Rotation Schedule

**Automated Rotation with Cron:**

```cron
# /etc/cron.d/llm-observatory-secrets

# Rotate database password every 90 days (quarterly)
0 2 1 */3 * cd /opt/llm-observatory && ./scripts/rotate-db-password.sh >> /var/log/llm-obs-rotation.log 2>&1

# Rotate application secrets every 180 days (semi-annually)
0 3 1 */6 * cd /opt/llm-observatory && ./scripts/rotate-app-secrets.sh >> /var/log/llm-obs-rotation.log 2>&1

# Rotate Redis password every 90 days
0 4 1 */3 * cd /opt/llm-observatory && ./scripts/rotate-redis-password.sh >> /var/log/llm-obs-rotation.log 2>&1
```

### Emergency Rotation

In case of suspected compromise:

```bash
#!/bin/bash
# emergency-rotation.sh - Rotate ALL secrets immediately

set -e

echo "EMERGENCY SECRET ROTATION INITIATED"
echo "This will cause brief service disruption"
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Aborted"
  exit 1
fi

# Rotate all secrets
./scripts/rotate-db-password.sh
./scripts/rotate-redis-password.sh
./scripts/rotate-app-secrets.sh
./scripts/rotate-grafana-password.sh

# Notify team
./scripts/send-alert.sh "EMERGENCY: All secrets rotated due to security incident"

# Log incident
echo "$(date -u +"%Y-%m-%d %H:%M:%S UTC") - EMERGENCY ROTATION" >> secrets/rotation.log

echo "Emergency rotation complete!"
```

## Backup and Recovery

### Secret Backup

**Encrypted Backup:**

```bash
#!/bin/bash
# backup-secrets.sh

set -e

BACKUP_DIR="secrets/backups"
BACKUP_FILE="secrets-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
ENCRYPTION_KEY="secrets/backup_encryption_key.txt"

mkdir -p "$BACKUP_DIR"

# Create encrypted archive
tar czf - secrets/*.txt | \
  openssl enc -aes-256-cbc -salt -pbkdf2 -pass file:"$ENCRYPTION_KEY" \
  > "$BACKUP_DIR/$BACKUP_FILE.enc"

# Upload to S3
aws s3 cp "$BACKUP_DIR/$BACKUP_FILE.enc" \
  "s3://llm-observatory-backups/secrets/$BACKUP_FILE.enc" \
  --storage-class GLACIER

# Keep only last 10 local backups
ls -t "$BACKUP_DIR"/*.enc | tail -n +11 | xargs -r rm

echo "Secrets backed up: $BACKUP_FILE.enc"
```

### Secret Recovery

```bash
#!/bin/bash
# restore-secrets.sh

set -e

BACKUP_FILE=$1
ENCRYPTION_KEY="secrets/backup_encryption_key.txt"

if [ -z "$BACKUP_FILE" ]; then
  echo "Usage: $0 <backup-file>"
  exit 1
fi

# Decrypt and extract
openssl enc -aes-256-cbc -d -pbkdf2 -pass file:"$ENCRYPTION_KEY" \
  -in "$BACKUP_FILE" | tar xzf -

echo "Secrets restored from $BACKUP_FILE"
echo "Restart services to apply: docker compose -f docker-compose.prod.yml restart"
```

### Disaster Recovery

**Master Key Recovery (Break Glass Procedure):**

```bash
# Store master keys in secure location (e.g., physical safe)
# Keep printed copies in sealed envelopes
# Distribute to trusted personnel

# To recover from complete secret loss:

# 1. Retrieve master keys from secure storage
# 2. Initialize secret manager
# 3. Restore from encrypted backup
aws s3 cp s3://llm-observatory-backups/secrets/latest.tar.gz.enc .
./restore-secrets.sh latest.tar.gz.enc

# 4. Verify all secrets present
./scripts/verify-secrets.sh

# 5. Restart services
docker compose -f docker-compose.prod.yml down
docker compose -f docker-compose.prod.yml up -d

# 6. Rotate all secrets immediately (compromised)
./scripts/emergency-rotation.sh

# 7. Update documentation
# 8. Conduct post-incident review
```

## Audit and Compliance

### Access Logging

**Enable AWS CloudTrail for Secrets Manager:**

```bash
# Create CloudTrail trail
aws cloudtrail create-trail \
  --name llm-observatory-secrets-audit \
  --s3-bucket-name llm-observatory-audit-logs

aws cloudtrail start-logging --name llm-observatory-secrets-audit

# Create SNS topic for alerts
aws sns create-topic --name secrets-access-alerts

# Subscribe to alerts
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:123456789012:secrets-access-alerts \
  --protocol email \
  --notification-endpoint security@yourdomain.com
```

**Query Access Logs:**

```bash
# Find who accessed a secret
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=llm-observatory/prod/db-password \
  --max-results 50 \
  --query 'Events[*].[EventTime,Username,EventName]' \
  --output table
```

### Compliance Checklist

**GDPR/CCPA:**
- [ ] Secrets encrypted at rest
- [ ] Secrets encrypted in transit
- [ ] Access logs retained for 1+ years
- [ ] Right to deletion implemented
- [ ] Data breach notification procedure established

**SOC 2:**
- [ ] Secret rotation policy documented
- [ ] Access control matrix maintained
- [ ] Audit logs immutable
- [ ] Regular access reviews conducted
- [ ] Encryption key management documented

**HIPAA (if applicable):**
- [ ] Secrets stored in HIPAA-compliant service
- [ ] Business Associate Agreement (BAA) signed
- [ ] Access logs reviewed quarterly
- [ ] Encryption validated annually
- [ ] Incident response plan tested

**PCI DSS (if processing payments):**
- [ ] Secrets rotated quarterly minimum
- [ ] Encryption uses approved algorithms (AES-256)
- [ ] Access limited to need-to-know basis
- [ ] Key management procedures documented
- [ ] Annual security assessment completed

### Audit Reports

**Generate Audit Report:**

```bash
#!/bin/bash
# generate-audit-report.sh

REPORT_FILE="secrets-audit-report-$(date +%Y%m%d).md"

cat > "$REPORT_FILE" <<EOF
# Secrets Audit Report

**Date:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Generated By:** $(whoami)

## Secret Inventory

$(ls -lh secrets/*.txt | awk '{print "- " $9}')

## Last Rotation

$(cat secrets/rotation.log | tail -n 10)

## Access Control

$(ls -la secrets/ | head -n 20)

## Compliance Status

- [ ] All secrets rotated within policy timeframe
- [ ] No world-readable secret files
- [ ] Backup completed within last 7 days
- [ ] Access logs reviewed
- [ ] No unauthorized access detected

## Recommendations

[Add recommendations based on findings]

---
Next Audit: $(date -u -d "+90 days" +"%Y-%m-%d")
EOF

echo "Audit report generated: $REPORT_FILE"
```

## Troubleshooting

### Common Issues

**1. Secret Not Found**

```bash
# Verify secret file exists
ls -lh secrets/db_password.txt

# Check permissions
stat secrets/db_password.txt

# Verify content is not empty
wc -l secrets/db_password.txt

# Check Docker can access
docker run --rm -v $(pwd)/secrets:/secrets:ro alpine cat /secrets/db_password.txt
```

**2. Permission Denied**

```bash
# Fix ownership
sudo chown 1000:1000 secrets/*.txt

# Fix permissions
chmod 600 secrets/*.txt
chmod 700 secrets/
```

**3. Invalid Secret Format**

```bash
# Check for newlines/whitespace
hexdump -C secrets/db_password.txt

# Clean secret (remove trailing newlines)
tr -d '\n' < secrets/db_password.txt > secrets/db_password.txt.clean
mv secrets/db_password.txt.clean secrets/db_password.txt
```

**4. Secret Service Unavailable**

```bash
# Check AWS Secrets Manager
aws secretsmanager describe-secret --secret-id llm-observatory/prod/db-password

# Check Vault
vault status
vault kv get llm-observatory/prod/database

# Fallback to local secrets
export USE_LOCAL_SECRETS=true
docker compose -f docker-compose.prod.yml up -d
```

**5. Container Cannot Read Secret**

```bash
# Verify secret mounted
docker compose -f docker-compose.prod.yml exec api-server ls -la /run/secrets/

# Check file content
docker compose -f docker-compose.prod.yml exec api-server cat /run/secrets/db_password

# Check container user has permissions
docker compose -f docker-compose.prod.yml exec api-server id
```

### Debug Commands

```bash
# List all secrets
find secrets/ -type f -name "*.txt"

# Verify no empty secrets
find secrets/ -type f -name "*.txt" -empty

# Check secret file sizes
du -h secrets/*.txt

# Verify encryption key strength
openssl rand -base64 32 | wc -c  # Should be 44+

# Test secret manager connectivity
aws secretsmanager list-secrets | grep llm-observatory

# Audit secret access
grep "secrets" /var/log/syslog
docker compose -f docker-compose.prod.yml logs | grep -i secret | grep -i error
```

## Security Incident Response

### Suspected Secret Compromise

**Immediate Actions:**

1. **Isolate:**
   ```bash
   # Disable compromised secret
   aws secretsmanager update-secret-version-stage \
     --secret-id llm-observatory/prod/db-password \
     --version-stage AWSCURRENT \
     --remove-from-version-id <current-version-id>
   ```

2. **Rotate:**
   ```bash
   ./scripts/emergency-rotation.sh
   ```

3. **Investigate:**
   ```bash
   # Check access logs
   aws cloudtrail lookup-events \
     --lookup-attributes AttributeKey=ResourceName,AttributeValue=llm-observatory/prod/db-password \
     --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
     --query 'Events[*].[EventTime,Username,SourceIPAddress,EventName]' \
     --output table

   # Check application logs
   docker compose -f docker-compose.prod.yml logs --since 7d | grep -i auth | grep -i fail
   ```

4. **Notify:**
   ```bash
   # Alert security team
   ./scripts/send-alert.sh "SECURITY: Potential secret compromise detected"

   # Document incident
   cat >> secrets/incidents.log <<EOF
$(date -u +"%Y-%m-%d %H:%M:%S UTC") - Suspected compromise: [describe]
Actions taken: Emergency rotation completed
Notified: security@yourdomain.com
Status: Under investigation
EOF
   ```

5. **Review:**
   - Conduct post-incident review
   - Update procedures if needed
   - Strengthen access controls
   - Implement additional monitoring

---

**Next Steps:**
- [Production Deployment Guide](./PRODUCTION_DEPLOYMENT.md)
- [Production Checklist](./PRODUCTION_CHECKLIST.md)
- [Operations Manual](./OPERATIONS_MANUAL.md)
