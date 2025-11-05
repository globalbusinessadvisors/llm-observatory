# API Service Security Checklist

This checklist ensures the API service is production-ready with proper security configurations.

## Pre-Production Security Checklist

### Authentication & Authorization

- [x] JWT authentication implemented
- [x] JWT secret configured via environment variable (not hardcoded)
- [x] JWT token expiration set (default: 1 hour)
- [x] Refresh token support (7 days)
- [x] API key authentication support
- [x] Role-based access control (RBAC) configured
- [x] Default role assigned (viewer)
- [ ] **ACTION REQUIRED**: Generate secure JWT_SECRET: `openssl rand -hex 32`
- [ ] **ACTION REQUIRED**: Generate secure SECRET_KEY: `openssl rand -hex 32`

### CORS Configuration

- [x] CORS enabled with configurable origins
- [x] Default production origins set
- [x] Credentials support configurable
- [x] Allowed methods restricted
- [x] Allowed headers specified
- [ ] **ACTION REQUIRED**: Set CORS_ORIGINS to actual domain(s)
- [x] Development mode uses permissive settings (*)

### Rate Limiting

- [x] Rate limiting enabled by default
- [x] Per-endpoint limits configured
- [x] Per-role limits configured
- [x] Redis-backed storage
- [x] Rate limit headers included in responses
- [x] Configurable via environment variables
- [x] Can be disabled for development

### Database Security

- [x] Read-only database user used
- [x] Connection pooling configured
- [x] Pool size limits set
- [x] Connection timeout configured
- [x] Query logging can be disabled
- [ ] **ACTION REQUIRED**: Ensure DB_READONLY_USER has minimal permissions
- [ ] **ACTION REQUIRED**: Rotate database credentials regularly

### Container Security

- [x] Non-root user (uid:1000, gid:1000)
- [x] No new privileges flag set
- [x] All capabilities dropped
- [x] Only NET_BIND_SERVICE capability added
- [x] Tmpfs for temporary files
- [x] Security labels configured
- [x] Health checks implemented
- [x] Resource limits recommended in documentation

### GraphQL Security

- [x] Playground disabled in production
- [x] Introspection disabled in production
- [x] Max query depth limit (10)
- [x] Max query complexity limit (1000)
- [x] Query timeout configured (30s)
- [x] Configurable per environment
- [x] Development mode enables playground/introspection

### Network Security

- [x] Services isolated in Docker network
- [x] Only necessary ports exposed
- [x] Metrics on separate port
- [x] Internal communication over Docker network
- [ ] **ACTION REQUIRED**: Configure reverse proxy/load balancer with SSL/TLS
- [ ] **ACTION REQUIRED**: Set up network policies if using Kubernetes

### Security Headers

- [x] HSTS (Strict-Transport-Security) enabled
- [x] X-Frame-Options: DENY
- [x] X-Content-Type-Options: nosniff
- [x] X-XSS-Protection enabled
- [x] Referrer-Policy configured
- [x] Content-Security-Policy configured
- [x] Request ID tracking enabled

### Error Handling

- [x] Error details hidden in production
- [x] Stack traces disabled in production
- [x] Request ID included in errors
- [x] Sentry integration available
- [ ] **ACTION REQUIRED**: Configure SENTRY_DSN for error tracking

### Logging & Monitoring

- [x] JSON logging in production
- [x] Sensitive data logging disabled
- [x] Request/response logging configurable
- [x] Prometheus metrics exposed
- [x] Health check endpoints
- [x] OpenTelemetry tracing support
- [ ] **ACTION REQUIRED**: Configure log aggregation (Loki/ELK)
- [ ] **ACTION REQUIRED**: Set up alerting rules in Prometheus

### Input Validation

- [x] Strict validation enabled
- [x] Max string length enforced (10,000 chars)
- [x] Max array length enforced (1,000 items)
- [x] Max request body size (10MB)
- [x] Request timeout (30s)

### Caching Security

- [x] Redis password protected
- [x] Cache key prefix configured
- [x] TTL limits set
- [x] Cache can be disabled per endpoint
- [ ] **ACTION REQUIRED**: Rotate REDIS_PASSWORD regularly

### Secrets Management

- [x] All secrets via environment variables
- [x] No secrets in code
- [x] No secrets in logs
- [x] Configuration file mounted read-only
- [ ] **ACTION REQUIRED**: Use secrets manager (AWS Secrets Manager, Vault, etc.)
- [ ] **ACTION REQUIRED**: Enable secrets rotation

## Production Deployment Checklist

### Pre-Deployment

- [ ] All security secrets generated and stored securely
- [ ] Environment variables configured in `.env` (not `.env.example`)
- [ ] CORS_ORIGINS set to actual domains
- [ ] GRAPHQL_PLAYGROUND=false
- [ ] GRAPHQL_INTROSPECTION=false
- [ ] RATE_LIMIT_ENABLED=true
- [ ] LOG_LEVEL=info (not debug)
- [ ] Database credentials secured
- [ ] Redis password secured
- [ ] SSL/TLS certificates obtained
- [ ] Reverse proxy configured (nginx/Traefik/ALB)

### Deployment

- [ ] Database migrations applied
- [ ] Read-only database user created and tested
- [ ] Health checks passing
- [ ] Metrics endpoint accessible to Prometheus
- [ ] Resource limits set (CPU/Memory)
- [ ] Horizontal scaling tested (if applicable)
- [ ] Load balancer configured
- [ ] DNS configured
- [ ] SSL/TLS enabled and tested

### Post-Deployment

- [ ] Smoke tests passed
- [ ] Authentication tested
- [ ] Rate limiting tested
- [ ] CORS tested from frontend
- [ ] Metrics appearing in Prometheus
- [ ] Logs flowing to aggregation system
- [ ] Alerts configured and tested
- [ ] Documentation updated
- [ ] Team trained on operations

## Security Monitoring

### Continuous Monitoring

- [ ] Failed authentication attempts monitored
- [ ] Rate limit violations tracked
- [ ] Unusual traffic patterns detected
- [ ] Error rates monitored
- [ ] Response times tracked
- [ ] Database query performance monitored
- [ ] Cache hit rate monitored

### Alerting Rules

Example alerts to configure:

1. **High Authentication Failures**: >10 failures/min from same IP
2. **Rate Limit Exceeded**: >100 violations/min
3. **High Error Rate**: >5% of requests
4. **Slow Response Time**: p95 >1s
5. **Database Issues**: Connection pool >80% utilized
6. **Cache Issues**: Hit rate <50%
7. **Health Check Failures**: Service unhealthy for >1 min

## Compliance & Best Practices

### OWASP API Security Top 10

- [x] API1: Broken Object Level Authorization - RBAC implemented
- [x] API2: Broken User Authentication - JWT authentication
- [x] API3: Excessive Data Exposure - Field-level permissions in GraphQL
- [x] API4: Lack of Resources & Rate Limiting - Rate limiting configured
- [x] API5: Broken Function Level Authorization - Role-based access
- [x] API6: Mass Assignment - Input validation
- [x] API7: Security Misconfiguration - Security headers, CORS
- [x] API8: Injection - Parameterized queries (SQLx)
- [x] API9: Improper Assets Management - API versioning (/api/v1)
- [x] API10: Insufficient Logging & Monitoring - Comprehensive logging

### Regular Security Tasks

**Daily**
- [ ] Review error logs
- [ ] Check authentication failures
- [ ] Monitor rate limit violations

**Weekly**
- [ ] Review security alerts
- [ ] Check dependency updates
- [ ] Review access logs for anomalies

**Monthly**
- [ ] Security audit
- [ ] Dependency vulnerability scan
- [ ] Access control review
- [ ] Secrets rotation

**Quarterly**
- [ ] Penetration testing
- [ ] Security configuration review
- [ ] Disaster recovery drill
- [ ] Compliance audit

## Security Incident Response

### Incident Response Plan

1. **Detection**: Monitor alerts and logs
2. **Containment**: Rate limiting, IP blocking, service isolation
3. **Investigation**: Review logs, traces, metrics
4. **Remediation**: Apply fixes, rotate credentials
5. **Recovery**: Restore service, verify security
6. **Post-Mortem**: Document incident, improve processes

### Emergency Contacts

- [ ] Security team contact configured
- [ ] On-call rotation established
- [ ] Escalation procedures documented
- [ ] Incident communication plan ready

## Tools & Resources

### Security Scanning

```bash
# Dependency vulnerability scan
cargo audit

# Container security scan
docker scan llm-observatory-api:latest

# Static analysis
cargo clippy -- -D warnings

# License compliance
cargo license
```

### Testing

```bash
# Load testing
k6 run tests/load/api-load-test.js

# Security testing
OWASP ZAP scan

# Penetration testing
Burp Suite Professional
```

### Documentation

- [OWASP API Security](https://owasp.org/www-project-api-security/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [Rust Security Guidelines](https://anssi-fr.github.io/rust-guide/)

## Sign-off

### Production Release Approval

- [ ] Security review completed: _________________ Date: _______
- [ ] Deployment checklist completed: ___________ Date: _______
- [ ] Testing completed: ________________________ Date: _______
- [ ] Documentation updated: ___________________ Date: _______
- [ ] Team lead approval: ______________________ Date: _______
- [ ] Security team approval: ___________________ Date: _______

**Release Version**: _____________
**Deployment Date**: _____________
**Deployed By**: _________________
