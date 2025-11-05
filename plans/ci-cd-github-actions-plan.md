# CI/CD Implementation Plan - GitHub Actions

**Project:** LLM Observatory Analytics API
**Version:** 1.0.0
**Status:** Implementation Plan
**Last Updated:** 2025-11-05

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [CI/CD Architecture](#cicd-architecture)
3. [GitHub Actions Workflows](#github-actions-workflows)
4. [Testing Strategy](#testing-strategy)
5. [Build Pipeline](#build-pipeline)
6. [Deployment Pipeline](#deployment-pipeline)
7. [Security & Compliance](#security--compliance)
8. [Release Management](#release-management)
9. [Monitoring & Observability](#monitoring--observability)
10. [Cost Optimization](#cost-optimization)
11. [Implementation Roadmap](#implementation-roadmap)

---

## Executive Summary

### Objectives

Implement an **enterprise-grade, commercially viable CI/CD pipeline** using GitHub Actions for the LLM Observatory Analytics API that provides:

- **Automated Testing**: Unit, integration, load, and security tests on every commit
- **Continuous Integration**: Build validation, code quality checks, and security scanning
- **Continuous Deployment**: Automated deployment to dev, staging, and production environments
- **Quality Gates**: Automated gates preventing bad code from reaching production
- **Fast Feedback**: < 10 minute CI pipeline for rapid iteration
- **High Reliability**: 99.9% pipeline availability with rollback capabilities
- **Cost Efficiency**: Optimized runner usage and caching strategies

### Success Criteria

| Metric | Target |
|--------|--------|
| **CI Pipeline Time** | < 10 minutes (P95) |
| **Test Coverage** | > 90% |
| **Deployment Time** | < 5 minutes (dev/staging), < 15 minutes (production) |
| **Pipeline Success Rate** | > 95% |
| **Security Scan** | Zero critical vulnerabilities allowed |
| **False Positive Rate** | < 5% |
| **Cost per Deployment** | < $2 |

---

## CI/CD Architecture

### Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CODE COMMIT (Push/PR)                        │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    CONTINUOUS INTEGRATION (CI)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │  Code Lint   │  │  Unit Tests  │  │ Security     │             │
│  │  & Format    │  │  (90%+ cov)  │  │ Scanning     │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
│                                                                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │
│  │ Integration  │  │    Build     │  │  Container   │             │
│  │    Tests     │  │   Binary     │  │    Image     │             │
│  └──────────────┘  └──────────────┘  └──────────────┘             │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ (All checks pass)
                               ▼
┌─────────────────────────────────────────────────────────────────────┐
│                   CONTINUOUS DEPLOYMENT (CD)                         │
│                                                                       │
│  ┌───────────────────────────────────────────────────────────┐     │
│  │  Development (auto-deploy on main)                         │     │
│  │  ├─ Deploy to dev cluster                                  │     │
│  │  ├─ Smoke tests                                            │     │
│  │  └─ Integration tests                                      │     │
│  └───────────────────────────────────────────────────────────┘     │
│                                                                       │
│  ┌───────────────────────────────────────────────────────────┐     │
│  │  Staging (auto-deploy on release branch)                   │     │
│  │  ├─ Deploy to staging cluster                              │     │
│  │  ├─ Smoke tests                                            │     │
│  │  ├─ Load tests (100 RPS for 5 min)                        │     │
│  │  └─ Manual approval gate                                   │     │
│  └───────────────────────────────────────────────────────────┘     │
│                                                                       │
│  ┌───────────────────────────────────────────────────────────┐     │
│  │  Production (manual trigger on tags)                       │     │
│  │  ├─ Blue-green deployment                                  │     │
│  │  ├─ Health checks                                          │     │
│  │  ├─ Canary testing (5% traffic)                           │     │
│  │  ├─ Monitor for 10 minutes                                │     │
│  │  ├─ Full traffic switch                                    │     │
│  │  └─ Auto-rollback on errors                               │     │
│  └───────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────┘
```

### Environment Strategy

| Environment | Trigger | Auto-Deploy | Purpose |
|-------------|---------|-------------|---------|
| **Development** | Push to `main` | Yes | Rapid iteration, latest features |
| **Staging** | Push to `release/*` | Yes + Manual Gate | Pre-production validation, load testing |
| **Production** | Git tag `v*.*.*` | Manual Trigger | Live customer traffic |

---

## GitHub Actions Workflows

### Workflow Structure

```
.github/
└── workflows/
    ├── ci.yml                      # Main CI pipeline (on every PR/push)
    ├── cd-dev.yml                  # Deploy to development
    ├── cd-staging.yml              # Deploy to staging
    ├── cd-production.yml           # Deploy to production
    ├── security-scan.yml           # Daily security scans
    ├── performance-benchmark.yml   # Weekly performance benchmarks
    └── cleanup.yml                 # Cleanup old artifacts
```

---

## 1. Main CI Pipeline

**File:** `.github/workflows/ci.yml`

**Triggers:**
- Pull requests to `main`
- Pushes to `main`, `develop`, `release/*`

**Jobs:**
1. Code Quality Check
2. Unit Tests
3. Integration Tests
4. Security Scanning
5. Build & Containerize

**Workflow:**

```yaml
name: CI Pipeline

on:
  pull_request:
    branches: [main, develop, release/*]
  push:
    branches: [main, develop, release/*]

env:
  CARGO_TERM_COLOR: always
  RUST_BACKTRACE: 1
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}/analytics-api

jobs:
  # ============================================================
  # Job 1: Code Quality & Linting
  # ============================================================
  code-quality:
    name: Code Quality
    runs-on: ubuntu-latest
    timeout-minutes: 10

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Rust toolchain
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          profile: minimal
          components: rustfmt, clippy
          override: true

      - name: Cache cargo registry
        uses: actions/cache@v4
        with:
          path: ~/.cargo/registry
          key: ${{ runner.os }}-cargo-registry-${{ hashFiles('**/Cargo.lock') }}

      - name: Cache cargo index
        uses: actions/cache@v4
        with:
          path: ~/.cargo/git
          key: ${{ runner.os }}-cargo-git-${{ hashFiles('**/Cargo.lock') }}

      - name: Cache cargo build
        uses: actions/cache@v4
        with:
          path: target
          key: ${{ runner.os }}-cargo-build-${{ hashFiles('**/Cargo.lock') }}

      - name: Check code formatting
        run: cargo fmt --all -- --check
        working-directory: services/analytics-api

      - name: Run clippy
        run: cargo clippy --all-targets --all-features -- -D warnings
        working-directory: services/analytics-api

      - name: Check documentation
        run: cargo doc --no-deps --all-features
        env:
          RUSTDOCFLAGS: "-D warnings"
        working-directory: services/analytics-api

  # ============================================================
  # Job 2: Unit Tests
  # ============================================================
  unit-tests:
    name: Unit Tests
    runs-on: ubuntu-latest
    timeout-minutes: 15

    services:
      postgres:
        image: timescale/timescaledb:latest-pg15
        env:
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_password
          POSTGRES_DB: test_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

      redis:
        image: redis:7-alpine
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Rust toolchain
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          profile: minimal
          override: true

      - name: Restore cargo cache
        uses: actions/cache@v4
        with:
          path: |
            ~/.cargo/registry
            ~/.cargo/git
            target
          key: ${{ runner.os }}-cargo-test-${{ hashFiles('**/Cargo.lock') }}

      - name: Install sqlx-cli
        run: cargo install sqlx-cli --no-default-features --features postgres

      - name: Run database migrations
        env:
          DATABASE_URL: postgres://test_user:test_password@localhost:5432/test_db
        run: |
          cd crates/storage
          sqlx migrate run

      - name: Run unit tests with coverage
        env:
          DATABASE_URL: postgres://test_user:test_password@localhost:5432/test_db
          REDIS_URL: redis://localhost:6379/0
          JWT_SECRET: test-secret-key-for-ci-testing-only-minimum-32-chars
        run: |
          cargo install cargo-tarpaulin
          cargo tarpaulin --out Xml --output-dir ./coverage --workspace --exclude-files 'target/*'
        working-directory: services/analytics-api

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v4
        with:
          files: ./services/analytics-api/coverage/cobertura.xml
          flags: unittests
          name: unit-tests
          fail_ci_if_error: true

      - name: Check test coverage threshold
        run: |
          COVERAGE=$(grep -oP 'line-rate="\K[0-9.]+' coverage/cobertura.xml | head -1)
          COVERAGE_PCT=$(echo "$COVERAGE * 100" | bc)
          echo "Coverage: $COVERAGE_PCT%"
          if (( $(echo "$COVERAGE_PCT < 90" | bc -l) )); then
            echo "❌ Coverage $COVERAGE_PCT% is below 90% threshold"
            exit 1
          fi
          echo "✅ Coverage $COVERAGE_PCT% meets threshold"
        working-directory: services/analytics-api

  # ============================================================
  # Job 3: Integration Tests
  # ============================================================
  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest
    timeout-minutes: 20
    needs: [code-quality]

    services:
      postgres:
        image: timescale/timescaledb:latest-pg15
        env:
          POSTGRES_USER: test_user
          POSTGRES_PASSWORD: test_password
          POSTGRES_DB: test_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

      redis:
        image: redis:7-alpine
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Rust toolchain
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          profile: minimal
          override: true

      - name: Restore cargo cache
        uses: actions/cache@v4
        with:
          path: |
            ~/.cargo/registry
            ~/.cargo/git
            target
          key: ${{ runner.os }}-cargo-test-${{ hashFiles('**/Cargo.lock') }}

      - name: Install sqlx-cli
        run: cargo install sqlx-cli --no-default-features --features postgres

      - name: Run database migrations
        env:
          DATABASE_URL: postgres://test_user:test_password@localhost:5432/test_db
        run: |
          cd crates/storage
          sqlx migrate run

      - name: Run integration tests
        env:
          DATABASE_URL: postgres://test_user:test_password@localhost:5432/test_db
          REDIS_URL: redis://localhost:6379/0
          JWT_SECRET: test-secret-key-for-ci-testing-only-minimum-32-chars
          RUST_LOG: info
        run: cargo test --test '*' -- --test-threads=1
        working-directory: services/analytics-api

  # ============================================================
  # Job 4: Security Scanning
  # ============================================================
  security-scan:
    name: Security Scanning
    runs-on: ubuntu-latest
    timeout-minutes: 15

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Install Rust toolchain
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          profile: minimal
          override: true

      # Cargo Audit - Check for known vulnerabilities
      - name: Run cargo audit
        uses: actions-rs/audit-check@v1
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      # Cargo Deny - Check licenses and security advisories
      - name: Run cargo deny
        run: |
          cargo install cargo-deny
          cargo deny check
        working-directory: services/analytics-api

      # Trivy - Scan for vulnerabilities in dependencies
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: './services/analytics-api'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'

      - name: Upload Trivy results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

      # SAST with Semgrep
      - name: Run Semgrep
        uses: returntocorp/semgrep-action@v1
        with:
          config: >-
            p/security-audit
            p/rust
          generateSarif: true

      # Secret scanning
      - name: Gitleaks scan
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  # ============================================================
  # Job 5: Build & Containerize
  # ============================================================
  build:
    name: Build & Push Container
    runs-on: ubuntu-latest
    timeout-minutes: 30
    needs: [unit-tests, integration-tests, security-scan]
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix={{branch}}-

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: services/analytics-api/Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          build-args: |
            BUILDKIT_INLINE_CACHE=1

      - name: Scan container image
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-image-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'

      - name: Upload image scan results
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: 'trivy-image-results.sarif'

  # ============================================================
  # Job 6: Quality Gates
  # ============================================================
  quality-gates:
    name: Quality Gates
    runs-on: ubuntu-latest
    needs: [code-quality, unit-tests, integration-tests, security-scan, build]

    steps:
      - name: All quality checks passed
        run: |
          echo "✅ All quality gates passed:"
          echo "  - Code quality and linting"
          echo "  - Unit tests (90%+ coverage)"
          echo "  - Integration tests"
          echo "  - Security scanning (no critical issues)"
          echo "  - Container build and scan"
          echo ""
          echo "Ready for deployment!"
```

---

## 2. Development Deployment

**File:** `.github/workflows/cd-dev.yml`

**Triggers:**
- Successful CI pipeline on `main` branch

**Workflow:**

```yaml
name: Deploy to Development

on:
  workflow_run:
    workflows: ["CI Pipeline"]
    types: [completed]
    branches: [main]

env:
  ENVIRONMENT: development
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}/analytics-api

jobs:
  deploy-dev:
    name: Deploy to Development
    runs-on: ubuntu-latest
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    timeout-minutes: 10
    environment:
      name: development
      url: https://dev.api.llm-observatory.io

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure kubectl
        uses: azure/setup-kubectl@v3
        with:
          version: 'latest'

      - name: Set up kubeconfig
        run: |
          mkdir -p $HOME/.kube
          echo "${{ secrets.DEV_KUBECONFIG }}" | base64 -d > $HOME/.kube/config

      - name: Update deployment image
        run: |
          kubectl set image deployment/analytics-api \
            analytics-api=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }} \
            -n llm-observatory-dev

      - name: Wait for rollout
        run: |
          kubectl rollout status deployment/analytics-api \
            -n llm-observatory-dev \
            --timeout=5m

      - name: Run smoke tests
        run: |
          # Wait for service to be ready
          sleep 30

          # Health check
          curl -f https://dev.api.llm-observatory.io/health || exit 1

          # Metrics endpoint
          curl -f https://dev.api.llm-observatory.io/metrics || exit 1

          echo "✅ Smoke tests passed"

      - name: Notify deployment
        uses: 8398a7/action-slack@v3
        if: always()
        with:
          status: ${{ job.status }}
          text: |
            Development deployment ${{ job.status }}
            Commit: ${{ github.sha }}
            Author: ${{ github.actor }}
            URL: https://dev.api.llm-observatory.io
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

---

## 3. Staging Deployment

**File:** `.github/workflows/cd-staging.yml`

**Triggers:**
- Push to `release/*` branches
- Manual trigger

**Workflow:**

```yaml
name: Deploy to Staging

on:
  push:
    branches: [release/*]
  workflow_dispatch:
    inputs:
      image_tag:
        description: 'Docker image tag to deploy'
        required: true
        default: 'latest'

env:
  ENVIRONMENT: staging
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}/analytics-api

jobs:
  deploy-staging:
    name: Deploy to Staging
    runs-on: ubuntu-latest
    timeout-minutes: 15
    environment:
      name: staging
      url: https://staging.api.llm-observatory.io

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure kubectl
        uses: azure/setup-kubectl@v3

      - name: Set up kubeconfig
        run: |
          mkdir -p $HOME/.kube
          echo "${{ secrets.STAGING_KUBECONFIG }}" | base64 -d > $HOME/.kube/config

      - name: Determine image tag
        id: image
        run: |
          if [ "${{ github.event_name }}" == "workflow_dispatch" ]; then
            echo "tag=${{ github.event.inputs.image_tag }}" >> $GITHUB_OUTPUT
          else
            echo "tag=${{ github.sha }}" >> $GITHUB_OUTPUT
          fi

      - name: Update deployment image
        run: |
          kubectl set image deployment/analytics-api \
            analytics-api=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.image.outputs.tag }} \
            -n llm-observatory-staging

      - name: Wait for rollout
        run: |
          kubectl rollout status deployment/analytics-api \
            -n llm-observatory-staging \
            --timeout=10m

      - name: Run smoke tests
        run: |
          sleep 30
          curl -f https://staging.api.llm-observatory.io/health || exit 1
          curl -f https://staging.api.llm-observatory.io/metrics || exit 1
          echo "✅ Smoke tests passed"

      - name: Run load tests
        run: |
          # Install k6
          curl https://github.com/grafana/k6/releases/download/v0.47.0/k6-v0.47.0-linux-amd64.tar.gz -L | tar xvz
          sudo mv k6-v0.47.0-linux-amd64/k6 /usr/local/bin/

          # Run load test
          cat > load-test.js << 'EOF'
          import http from 'k6/http';
          import { check, sleep } from 'k6';

          export const options = {
            stages: [
              { duration: '1m', target: 50 },   // Ramp up
              { duration: '3m', target: 100 },  // Sustained load
              { duration: '1m', target: 0 },    // Ramp down
            ],
            thresholds: {
              http_req_duration: ['p(95)<500'], // 95% < 500ms
              http_req_failed: ['rate<0.01'],   // < 1% errors
            },
          };

          export default function () {
            const res = http.get('https://staging.api.llm-observatory.io/health');
            check(res, { 'status is 200': (r) => r.status === 200 });
            sleep(1);
          }
          EOF

          k6 run load-test.js || exit 1
          echo "✅ Load tests passed"

      - name: Notify deployment
        uses: 8398a7/action-slack@v3
        if: always()
        with:
          status: ${{ job.status }}
          text: |
            Staging deployment ${{ job.status }}
            Image: ${{ steps.image.outputs.tag }}
            URL: https://staging.api.llm-observatory.io
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}

  manual-approval:
    name: Manual Approval for Production
    runs-on: ubuntu-latest
    needs: deploy-staging
    environment:
      name: production-approval

    steps:
      - name: Request approval
        run: |
          echo "Staging deployment successful"
          echo "Awaiting manual approval for production promotion"
```

---

## 4. Production Deployment

**File:** `.github/workflows/cd-production.yml`

**Triggers:**
- Git tags matching `v*.*.*`
- Manual trigger with approval

**Workflow:**

```yaml
name: Deploy to Production

on:
  push:
    tags:
      - 'v*.*.*'
  workflow_dispatch:
    inputs:
      image_tag:
        description: 'Docker image tag to deploy (e.g., v1.0.0)'
        required: true

env:
  ENVIRONMENT: production
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}/analytics-api

jobs:
  pre-deployment-checks:
    name: Pre-Deployment Checks
    runs-on: ubuntu-latest
    timeout-minutes: 5

    steps:
      - name: Verify image exists
        run: |
          IMAGE_TAG="${{ github.ref_name }}"
          if [ "${{ github.event_name }}" == "workflow_dispatch" ]; then
            IMAGE_TAG="${{ github.event.inputs.image_tag }}"
          fi

          # Check if image exists in registry
          docker manifest inspect ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${IMAGE_TAG} || exit 1
          echo "✅ Image verified: ${IMAGE_TAG}"

      - name: Check staging health
        run: |
          # Verify staging is healthy before prod deployment
          curl -f https://staging.api.llm-observatory.io/health || exit 1
          echo "✅ Staging is healthy"

  deploy-production:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: pre-deployment-checks
    timeout-minutes: 30
    environment:
      name: production
      url: https://api.llm-observatory.io

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure kubectl
        uses: azure/setup-kubectl@v3

      - name: Set up kubeconfig
        run: |
          mkdir -p $HOME/.kube
          echo "${{ secrets.PROD_KUBECONFIG }}" | base64 -d > $HOME/.kube/config

      - name: Determine image tag
        id: image
        run: |
          if [ "${{ github.event_name }}" == "workflow_dispatch" ]; then
            echo "tag=${{ github.event.inputs.image_tag }}" >> $GITHUB_OUTPUT
          else
            echo "tag=${{ github.ref_name }}" >> $GITHUB_OUTPUT
          fi

      - name: Create new deployment (green)
        run: |
          # Create green deployment
          kubectl get deployment analytics-api-blue -n llm-observatory -o yaml | \
            sed 's/analytics-api-blue/analytics-api-green/g' | \
            sed "s|image:.*|image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.image.outputs.tag }}|" | \
            kubectl apply -f -

      - name: Wait for green deployment
        run: |
          kubectl rollout status deployment/analytics-api-green \
            -n llm-observatory \
            --timeout=10m

      - name: Run smoke tests on green
        run: |
          # Get green service IP
          GREEN_IP=$(kubectl get svc analytics-api-green -n llm-observatory -o jsonpath='{.spec.clusterIP}')

          # Health check
          kubectl run smoke-test --rm -i --restart=Never --image=curlimages/curl -- \
            curl -f http://${GREEN_IP}:8080/health || exit 1

          echo "✅ Green deployment smoke tests passed"

      - name: Canary deployment (5% traffic)
        run: |
          # Update ingress to send 5% traffic to green
          kubectl patch ingress analytics-api -n llm-observatory --type=json \
            -p='[{"op": "add", "path": "/metadata/annotations/nginx.ingress.kubernetes.io~1canary", "value": "true"},
                 {"op": "add", "path": "/metadata/annotations/nginx.ingress.kubernetes.io~1canary-weight", "value": "5"}]'

          echo "✅ Canary deployment active (5% traffic)"

      - name: Monitor canary (10 minutes)
        run: |
          echo "Monitoring canary deployment for 10 minutes..."

          for i in {1..10}; do
            echo "Minute $i/10: Checking error rate..."

            # Query Prometheus for error rate
            ERROR_RATE=$(curl -s "http://prometheus:9090/api/v1/query?query=rate(http_requests_total{status=~\"5..\",deployment=\"analytics-api-green\"}[1m])" | \
              jq -r '.data.result[0].value[1] // "0"')

            if (( $(echo "$ERROR_RATE > 0.01" | bc -l) )); then
              echo "❌ Error rate ${ERROR_RATE} exceeds threshold (0.01)"
              echo "ROLLBACK=true" >> $GITHUB_ENV
              break
            fi

            sleep 60
          done

          if [ -z "$ROLLBACK" ]; then
            echo "✅ Canary monitoring successful"
          fi

      - name: Rollback on failure
        if: env.ROLLBACK == 'true'
        run: |
          echo "⚠️  Rolling back deployment..."

          # Remove canary
          kubectl patch ingress analytics-api -n llm-observatory --type=json \
            -p='[{"op": "remove", "path": "/metadata/annotations/nginx.ingress.kubernetes.io~1canary"}]'

          # Scale down green
          kubectl scale deployment analytics-api-green -n llm-observatory --replicas=0

          echo "✅ Rollback complete"
          exit 1

      - name: Full traffic switch
        if: env.ROLLBACK != 'true'
        run: |
          # Switch 100% traffic to green
          kubectl patch service analytics-api -n llm-observatory -p \
            '{"spec":{"selector":{"version":"green"}}}'

          # Remove canary annotations
          kubectl patch ingress analytics-api -n llm-observatory --type=json \
            -p='[{"op": "remove", "path": "/metadata/annotations/nginx.ingress.kubernetes.io~1canary"}]'

          echo "✅ Traffic switched to green deployment"

      - name: Scale down blue deployment
        if: env.ROLLBACK != 'true'
        run: |
          # Wait 5 minutes before scaling down blue
          sleep 300

          kubectl scale deployment analytics-api-blue -n llm-observatory --replicas=0

          echo "✅ Blue deployment scaled down"

      - name: Promote green to blue
        if: env.ROLLBACK != 'true'
        run: |
          # Rename green to blue for next deployment
          kubectl get deployment analytics-api-green -n llm-observatory -o yaml | \
            sed 's/analytics-api-green/analytics-api-blue/g' | \
            kubectl apply -f -

          kubectl delete deployment analytics-api-green -n llm-observatory

          echo "✅ Green promoted to blue"

      - name: Create GitHub release
        if: env.ROLLBACK != 'true' && github.event_name == 'push'
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: ${{ github.ref_name }}
          release_name: Release ${{ github.ref_name }}
          body: |
            ## Analytics API ${{ github.ref_name }}

            **Deployed to Production**

            ### Changes
            See [CHANGELOG.md](CHANGELOG.md) for details.

            ### Deployment Info
            - Image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.image.outputs.tag }}
            - Date: ${{ github.event.head_commit.timestamp }}
            - Commit: ${{ github.sha }}
          draft: false
          prerelease: false

      - name: Notify deployment
        if: always()
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: |
            🚀 Production deployment ${{ job.status }}
            Version: ${{ steps.image.outputs.tag }}
            Rollback: ${{ env.ROLLBACK || 'false' }}
            URL: https://api.llm-observatory.io
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

---

## 5. Security Scanning (Daily)

**File:** `.github/workflows/security-scan.yml`

**Triggers:**
- Daily at 2 AM UTC
- Manual trigger

**Workflow:**

```yaml
name: Daily Security Scan

on:
  schedule:
    - cron: '0 2 * * *'  # 2 AM UTC daily
  workflow_dispatch:

jobs:
  security-audit:
    name: Security Audit
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Run cargo audit
        uses: actions-rs/audit-check@v1
        with:
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Scan container images
        run: |
          ENVIRONMENTS=("development" "staging" "production")

          for ENV in "${ENVIRONMENTS[@]}"; do
            echo "Scanning ${ENV} image..."

            # Get currently deployed image
            IMAGE=$(kubectl get deployment analytics-api -n llm-observatory-${ENV} \
              -o jsonpath='{.spec.template.spec.containers[0].image}')

            # Scan image
            trivy image --severity CRITICAL,HIGH --exit-code 1 ${IMAGE}
          done

      - name: Create security report
        if: failure()
        run: |
          echo "Security vulnerabilities detected!" > security-report.md
          echo "Please review and address immediately." >> security-report.md

      - name: Create GitHub issue on failure
        if: failure()
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: '🚨 Security Vulnerabilities Detected',
              body: 'Daily security scan found critical vulnerabilities. Please review the workflow logs.',
              labels: ['security', 'critical']
            })
```

---

## Testing Strategy

### Test Pyramid

```
                 /\
                /  \
               /E2E \ ────────────── 5% (End-to-End, Manual)
              /______\
             /        \
            /   Integ  \ ──────────  15% (Integration Tests)
           /____________\
          /              \
         /   Unit Tests   \ ───────  80% (Unit Tests, Fast)
        /__________________\
```

### Test Coverage Requirements

| Test Type | Coverage Target | Execution Time | Frequency |
|-----------|----------------|----------------|-----------|
| **Unit Tests** | > 90% | < 3 minutes | Every commit |
| **Integration Tests** | > 70% | < 10 minutes | Every commit |
| **Load Tests** | Key endpoints | < 5 minutes | Staging only |
| **Security Tests** | 100% of attack vectors | < 5 minutes | Every commit |
| **E2E Tests** | Critical paths | < 15 minutes | Pre-production |

### Test Environments

```rust
// Example: Unit test with mocked dependencies
#[cfg(test)]
mod tests {
    use super::*;
    use mockall::predicate::*;

    #[tokio::test]
    async fn test_get_traces_success() {
        let mut mock_repo = MockTraceRepository::new();
        mock_repo
            .expect_list_traces()
            .with(predicate::always())
            .times(1)
            .returning(|_| Ok(vec![]));

        let service = TraceService::new(Arc::new(mock_repo));
        let result = service.get_traces(ListTracesQuery::default()).await;

        assert!(result.is_ok());
    }
}
```

```rust
// Example: Integration test with real database
#[tokio::test]
async fn integration_test_create_and_retrieve_trace() {
    let db_pool = setup_test_database().await;
    let repo = TraceRepository::new(db_pool);

    // Create trace
    let trace_id = TraceId::new();
    let trace = Trace { id: trace_id, /* ... */ };
    repo.create_trace(&trace).await.unwrap();

    // Retrieve trace
    let retrieved = repo.get_trace(trace_id).await.unwrap();
    assert_eq!(retrieved.id, trace_id);

    cleanup_test_database().await;
}
```

---

## Build Pipeline

### Optimization Strategies

1. **Cargo Caching**
   - Cache `~/.cargo/registry` (dependencies)
   - Cache `~/.cargo/git` (git dependencies)
   - Cache `target/` (build artifacts)
   - Expected speedup: 5-10x for cached builds

2. **Docker Layer Caching**
   - Use BuildKit with GitHub Actions cache
   - Multi-stage builds with dependency layer separation
   - Expected speedup: 3-5x for cached images

3. **Parallel Jobs**
   - Run independent jobs in parallel
   - Use job dependencies only when necessary
   - Expected speedup: 2-3x overall pipeline

### Build Metrics

Track and optimize:
- Total pipeline duration
- Cache hit rates
- Build artifact sizes
- Container image sizes

**Target Metrics:**
```
CI Pipeline (uncached): < 15 minutes
CI Pipeline (cached):   < 5 minutes
Container image size:   < 500 MB
```

---

## Deployment Pipeline

### Deployment Strategy: Blue-Green with Canary

**Phases:**

1. **Pre-deployment** (2 minutes)
   - Verify staging health
   - Check image availability
   - Review recent errors

2. **Deploy Green** (5 minutes)
   - Deploy new version to green environment
   - Run health checks
   - Run smoke tests

3. **Canary Testing** (10 minutes)
   - Route 5% traffic to green
   - Monitor error rates, latency
   - Auto-rollback on threshold breach

4. **Full Switch** (2 minutes)
   - Route 100% traffic to green
   - Monitor for 5 minutes
   - Scale down blue

**Total Deployment Time:** ~15 minutes

### Rollback Procedures

**Automatic Rollback Triggers:**
- Error rate > 1% for 2 minutes
- P95 latency > 2 seconds for 5 minutes
- Health check failures > 50%

**Manual Rollback:**
```bash
# Trigger rollback workflow
gh workflow run rollback.yml \
  -f environment=production \
  -f reason="High error rate"
```

**Rollback Time:** < 2 minutes

---

## Security & Compliance

### Security Scanning Tools

| Tool | Purpose | Frequency |
|------|---------|-----------|
| **cargo-audit** | Known vulnerabilities in Rust deps | Every commit |
| **cargo-deny** | License compliance, security advisories | Every commit |
| **Trivy** | Container image vulnerabilities | Every build + Daily |
| **Semgrep** | SAST (Static Application Security Testing) | Every commit |
| **Gitleaks** | Secret detection | Every commit |

### Compliance Requirements

**OWASP Top 10 Coverage:**
- ✅ A01: Broken Access Control - JWT + RBAC checks
- ✅ A02: Cryptographic Failures - Secrets scanning, TLS enforcement
- ✅ A03: Injection - SQL injection prevention (SQLx compile-time checks)
- ✅ A04: Insecure Design - Security review in PR templates
- ✅ A05: Security Misconfiguration - Container hardening, security headers
- ✅ A06: Vulnerable Components - Daily dependency scans
- ✅ A07: Authentication Failures - JWT best practices, rate limiting
- ✅ A08: Software Integrity - Signed containers, SBOM generation
- ✅ A09: Logging Failures - Structured logging, audit trails
- ✅ A10: SSRF - Input validation, network policies

### SBOM Generation

Generate Software Bill of Materials for compliance:

```yaml
- name: Generate SBOM
  uses: anchore/sbom-action@v0
  with:
    image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.sha }}
    format: spdx-json
    output-file: sbom.spdx.json

- name: Upload SBOM
  uses: actions/upload-artifact@v4
  with:
    name: sbom
    path: sbom.spdx.json
```

---

## Release Management

### Versioning Strategy

**Semantic Versioning (SemVer):**
- `MAJOR.MINOR.PATCH` (e.g., `v1.2.3`)
- **MAJOR:** Breaking API changes
- **MINOR:** New features (backward compatible)
- **PATCH:** Bug fixes

### Release Process

1. **Create Release Branch**
   ```bash
   git checkout -b release/v1.2.0
   ```

2. **Update Version**
   ```bash
   # Update Cargo.toml
   sed -i 's/version = "1.1.0"/version = "1.2.0"/' Cargo.toml

   # Update CHANGELOG.md
   echo "## [1.2.0] - $(date +%Y-%m-%d)" >> CHANGELOG.md
   ```

3. **Commit and Tag**
   ```bash
   git add Cargo.toml CHANGELOG.md
   git commit -m "chore: bump version to v1.2.0"
   git tag -a v1.2.0 -m "Release v1.2.0"
   git push origin release/v1.2.0 --tags
   ```

4. **Deploy to Staging**
   - Automatic deployment triggered by release branch
   - Run full test suite including load tests
   - Manual QA validation

5. **Deploy to Production**
   - Triggered by git tag
   - Blue-green deployment with canary
   - Automatic rollback on errors

6. **Create GitHub Release**
   - Automatically created by workflow
   - Includes changelog
   - Links to Docker image

### Hotfix Process

For critical production bugs:

1. **Create Hotfix Branch**
   ```bash
   git checkout -b hotfix/v1.2.1 v1.2.0
   ```

2. **Fix and Test**
   ```bash
   # Make fix
   git commit -m "fix: critical security issue"
   ```

3. **Fast-track Deployment**
   ```bash
   git tag v1.2.1
   git push origin hotfix/v1.2.1 --tags
   ```

4. **Emergency Deployment**
   - Skip canary phase (optional)
   - Deploy directly to production
   - Monitor closely

---

## Monitoring & Observability

### Pipeline Metrics

Track in Grafana dashboard:

1. **Pipeline Performance**
   - Total duration (P50, P95, P99)
   - Job duration breakdown
   - Cache hit rates
   - Success/failure rates

2. **Deployment Metrics**
   - Deployment frequency
   - Lead time (commit to production)
   - Time to recovery (MTTR)
   - Change failure rate

3. **Build Metrics**
   - Build duration
   - Artifact sizes
   - Test execution time
   - Dependency update lag

### Alerting

**Slack Notifications:**
- ✅ Successful production deployments
- ❌ Failed CI/CD pipelines
- ⚠️ Security vulnerabilities detected
- 📊 Weekly deployment summary

**PagerDuty Alerts:**
- 🚨 Production deployment failures
- 🚨 Rollback triggered
- 🚨 Critical security vulnerabilities

### DORA Metrics

Track DevOps Research and Assessment (DORA) metrics:

| Metric | Current | Target | Elite |
|--------|---------|--------|-------|
| **Deployment Frequency** | TBD | Daily | Multiple per day |
| **Lead Time** | TBD | < 1 hour | < 1 hour |
| **MTTR** | TBD | < 1 hour | < 1 hour |
| **Change Failure Rate** | TBD | < 15% | < 5% |

---

## Cost Optimization

### GitHub Actions Costs

**Runner Pricing:**
- Linux runner: $0.008/minute
- Estimated monthly usage: ~50,000 minutes
- Monthly cost: ~$400

### Optimization Strategies

1. **Use Self-Hosted Runners**
   - For long-running jobs (builds, tests)
   - Reduce costs by ~70%
   - Trade-off: Management overhead

2. **Aggressive Caching**
   - Cache Cargo dependencies
   - Cache Docker layers
   - Expected savings: 50% reduction in build time

3. **Parallel Job Execution**
   - Reduce total pipeline time
   - Increase concurrency for faster feedback

4. **Scheduled Job Optimization**
   - Run security scans during off-peak hours
   - Use longer intervals for non-critical scans

**Target Monthly Cost:** < $200

---

## Implementation Roadmap

### Phase 1: Foundation (Week 1)

**Goals:**
- Basic CI pipeline operational
- Unit and integration tests automated
- Docker image builds automated

**Tasks:**
- [ ] Create `.github/workflows/ci.yml`
- [ ] Set up cargo caching
- [ ] Configure PostgreSQL/Redis services for tests
- [ ] Implement code quality checks (rustfmt, clippy)
- [ ] Set up unit test execution with coverage
- [ ] Set up integration test execution
- [ ] Configure Docker build and push

**Success Criteria:**
- ✅ CI pipeline runs on every PR
- ✅ Tests pass with > 90% coverage
- ✅ Docker images pushed to registry
- ✅ Pipeline completes in < 15 minutes

---

### Phase 2: Security & Quality (Week 1)

**Goals:**
- Security scanning integrated
- Quality gates enforced
- SBOM generation

**Tasks:**
- [ ] Add cargo-audit checks
- [ ] Add Trivy vulnerability scanning
- [ ] Add Semgrep SAST scanning
- [ ] Add Gitleaks secret detection
- [ ] Configure quality gate enforcement
- [ ] Set up SBOM generation

**Success Criteria:**
- ✅ No critical vulnerabilities allowed
- ✅ All security scans passing
- ✅ SBOM generated for every build
- ✅ Failed builds block merges

---

### Phase 3: Development Deployment (Week 2)

**Goals:**
- Automated deployment to development
- Smoke tests automated
- Deployment notifications

**Tasks:**
- [ ] Create `.github/workflows/cd-dev.yml`
- [ ] Configure development Kubernetes cluster
- [ ] Set up kubeconfig secrets
- [ ] Implement smoke tests
- [ ] Set up Slack notifications
- [ ] Configure automatic deployment on main

**Success Criteria:**
- ✅ Auto-deploy to dev on main branch commits
- ✅ Smoke tests pass after deployment
- ✅ Deployment takes < 10 minutes
- ✅ Team notified of deployments

---

### Phase 4: Staging Deployment (Week 2)

**Goals:**
- Automated deployment to staging
- Load tests integrated
- Manual approval gates

**Tasks:**
- [ ] Create `.github/workflows/cd-staging.yml`
- [ ] Configure staging Kubernetes cluster
- [ ] Implement load tests with k6
- [ ] Set up manual approval environment
- [ ] Configure deployment from release branches

**Success Criteria:**
- ✅ Auto-deploy to staging on release branches
- ✅ Load tests pass (100 RPS sustained)
- ✅ Manual approval required for production
- ✅ Staging matches production config

---

### Phase 5: Production Deployment (Week 3)

**Goals:**
- Blue-green deployment to production
- Canary testing automated
- Automatic rollback on errors

**Tasks:**
- [ ] Create `.github/workflows/cd-production.yml`
- [ ] Configure production Kubernetes cluster
- [ ] Implement blue-green deployment strategy
- [ ] Set up canary testing (5% traffic)
- [ ] Implement automatic rollback
- [ ] Configure deployment from tags
- [ ] Set up GitHub releases

**Success Criteria:**
- ✅ Zero-downtime deployments
- ✅ Canary testing validates deployments
- ✅ Auto-rollback on error threshold
- ✅ Deployment takes < 15 minutes
- ✅ Rollback takes < 2 minutes

---

### Phase 6: Monitoring & Optimization (Week 3)

**Goals:**
- Pipeline metrics tracked
- DORA metrics implemented
- Cost optimization applied

**Tasks:**
- [ ] Set up Grafana dashboard for CI/CD metrics
- [ ] Implement DORA metrics tracking
- [ ] Configure comprehensive alerting
- [ ] Optimize cache strategies
- [ ] Evaluate self-hosted runners
- [ ] Document runbooks

**Success Criteria:**
- ✅ All metrics visible in dashboards
- ✅ Alerts configured and tested
- ✅ Pipeline time reduced by 30%
- ✅ Monthly costs < $200

---

### Phase 7: Advanced Features (Week 4)

**Goals:**
- Daily security scanning
- Performance benchmarking
- Advanced deployment strategies

**Tasks:**
- [ ] Create `.github/workflows/security-scan.yml`
- [ ] Create `.github/workflows/performance-benchmark.yml`
- [ ] Implement progressive delivery (feature flags)
- [ ] Set up automated dependency updates (Dependabot)
- [ ] Create deployment CLI tools
- [ ] Write comprehensive documentation

**Success Criteria:**
- ✅ Daily security scans operational
- ✅ Performance regressions caught automatically
- ✅ Feature flags integrated
- ✅ Dependencies auto-updated
- ✅ Full documentation published

---

## Success Metrics

### Week 1 Targets

- ✅ CI pipeline operational
- ✅ All tests automated
- ✅ Security scanning active
- ✅ Docker images building

### Week 2 Targets

- ✅ Dev environment auto-deploying
- ✅ Staging environment operational
- ✅ Load tests passing

### Week 3 Targets

- ✅ Production deployments automated
- ✅ Blue-green strategy working
- ✅ Rollbacks tested and validated

### Week 4 Targets

- ✅ All metrics tracked
- ✅ Costs optimized
- ✅ Documentation complete
- ✅ Team trained

---

## Repository Secrets Required

Configure the following secrets in GitHub repository settings:

| Secret | Description | Example |
|--------|-------------|---------|
| `GITHUB_TOKEN` | Automatically provided | - |
| `DEV_KUBECONFIG` | Base64-encoded kubeconfig for dev cluster | `cat ~/.kube/dev-config \| base64` |
| `STAGING_KUBECONFIG` | Base64-encoded kubeconfig for staging | `cat ~/.kube/staging-config \| base64` |
| `PROD_KUBECONFIG` | Base64-encoded kubeconfig for production | `cat ~/.kube/prod-config \| base64` |
| `SLACK_WEBHOOK` | Slack webhook URL for notifications | `https://hooks.slack.com/...` |
| `CODECOV_TOKEN` | Codecov token for coverage reports | `abc123...` |

---

## Best Practices

### 1. Pull Request Workflow

```yaml
# Always run full CI on PRs
# Block merges if any check fails
# Require approval from codeowners
# Squash merge to keep history clean
```

### 2. Commit Message Convention

```
type(scope): subject

body

footer
```

**Types:** `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

**Example:**
```
feat(api): add export endpoint for JSON format

Implement JSON export endpoint that allows users to download
their trace data in JSON format. Includes pagination and
streaming support for large datasets.

Closes #123
```

### 3. Branch Protection Rules

Enable on `main` branch:
- ✅ Require pull request reviews (2 approvers)
- ✅ Require status checks to pass
- ✅ Require branches to be up to date
- ✅ Require conversation resolution
- ✅ Restrict force pushes
- ✅ Restrict deletions

### 4. Dependency Management

```yaml
# Use Dependabot for automatic updates
# Group minor/patch updates
# Review major updates manually
# Keep security updates separate
```

**`.github/dependabot.yml`:**
```yaml
version: 2
updates:
  - package-ecosystem: "cargo"
    directory: "/services/analytics-api"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    groups:
      patch-updates:
        patterns:
          - "*"
        update-types:
          - "patch"
      minor-updates:
        patterns:
          - "*"
        update-types:
          - "minor"
```

---

## Troubleshooting

### Common Issues

**1. CI Pipeline Timeout**

**Symptom:** Jobs timeout after 6 hours
**Cause:** Slow network, cache misses
**Solution:**
```yaml
# Increase timeout
timeout-minutes: 30

# Improve caching
- uses: actions/cache@v4
  with:
    path: target
    key: ${{ runner.os }}-cargo-${{ hashFiles('**/Cargo.lock') }}
```

**2. Docker Build Failures**

**Symptom:** "No space left on device"
**Cause:** Insufficient disk space on runner
**Solution:**
```yaml
- name: Free up disk space
  run: |
    docker system prune -af
    sudo apt-get clean
```

**3. Kubernetes Deployment Failures**

**Symptom:** Pods not starting
**Cause:** Invalid kubeconfig, wrong namespace
**Solution:**
```yaml
# Verify kubeconfig
- name: Debug kubeconfig
  run: kubectl cluster-info

# Check namespace
- name: List namespaces
  run: kubectl get namespaces
```

**4. Test Failures in CI (Pass Locally)**

**Symptom:** Tests pass locally but fail in CI
**Cause:** Timing issues, environment differences
**Solution:**
```rust
// Use longer timeouts in CI
#[tokio::test]
#[ignore] // Run only in CI
async fn test_with_ci_timeout() {
    let timeout = if cfg!(ci) {
        Duration::from_secs(30)
    } else {
        Duration::from_secs(5)
    };
    // ...
}
```

---

## Appendix

### A. Workflow Files Checklist

- [ ] `.github/workflows/ci.yml` - Main CI pipeline
- [ ] `.github/workflows/cd-dev.yml` - Development deployment
- [ ] `.github/workflows/cd-staging.yml` - Staging deployment
- [ ] `.github/workflows/cd-production.yml` - Production deployment
- [ ] `.github/workflows/security-scan.yml` - Daily security scans
- [ ] `.github/workflows/performance-benchmark.yml` - Performance tests
- [ ] `.github/workflows/cleanup.yml` - Artifact cleanup
- [ ] `.github/dependabot.yml` - Dependency updates

### B. Documentation Checklist

- [ ] CI/CD architecture diagram
- [ ] Deployment runbook
- [ ] Rollback procedures
- [ ] Security scanning guide
- [ ] Cost optimization guide
- [ ] Troubleshooting guide
- [ ] Team onboarding guide

### C. Testing Checklist

- [ ] Unit tests with > 90% coverage
- [ ] Integration tests with real DB
- [ ] Load tests for staging
- [ ] Smoke tests for all environments
- [ ] Security tests (SAST, dependency scan)
- [ ] Container image scanning

### D. Monitoring Checklist

- [ ] CI/CD metrics dashboard
- [ ] DORA metrics tracking
- [ ] Pipeline performance alerts
- [ ] Security vulnerability alerts
- [ ] Cost tracking dashboard
- [ ] Deployment success/failure alerts

---

## Conclusion

This CI/CD implementation plan provides a **comprehensive, enterprise-grade, commercially viable** solution for the LLM Observatory Analytics API using GitHub Actions.

### Key Benefits

✅ **Fast Feedback:** < 10 minute CI pipeline
✅ **High Quality:** 90%+ test coverage, security scanning
✅ **Reliable Deployments:** Blue-green with automatic rollback
✅ **Cost Efficient:** < $200/month with optimization
✅ **Secure:** Multiple security scanning layers
✅ **Observable:** Full metrics and alerting
✅ **Scalable:** Multi-environment support

### Next Steps

1. **Week 1:** Implement Phase 1-2 (CI + Security)
2. **Week 2:** Implement Phase 3-4 (Dev + Staging)
3. **Week 3:** Implement Phase 5-6 (Production + Monitoring)
4. **Week 4:** Implement Phase 7 (Advanced features)

### Success Criteria

At the end of the 4-week implementation:

- ✅ All environments deploying automatically
- ✅ 100% of commits going through CI/CD
- ✅ Zero manual deployments
- ✅ < 1 hour lead time from commit to production
- ✅ > 95% pipeline success rate
- ✅ Team fully trained and confident

---

**Document Version:** 1.0.0
**Last Updated:** 2025-11-05
**Status:** ✅ Ready for Implementation
