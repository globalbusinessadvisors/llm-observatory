.PHONY: help dev-start dev-stop dev-restart dev-logs dev-clean dev-rebuild dev-seed dev-reset dev-shell dev-test format lint check build test \
        test-all test-unit test-integration test-coverage test-docker test-parallel \
        start-test-db stop-test-db seed-test-data ci-test ci-coverage clean-test

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m # No Color

# Docker compose files
COMPOSE_FILES := -f docker-compose.yml -f docker/compose/docker-compose.dev.yml

help: ## Show this help message
	@echo "$(BLUE)LLM Observatory - Development Commands$(NC)"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""

# =============================================================================
# Development Environment
# =============================================================================

dev-start: ## Start development environment with hot reload
	@echo "$(BLUE)Starting development environment...$(NC)"
	docker-compose $(COMPOSE_FILES) up

dev-start-d: ## Start development environment in background
	@echo "$(BLUE)Starting development environment in background...$(NC)"
	docker-compose $(COMPOSE_FILES) up -d

dev-stop: ## Stop development environment
	@echo "$(BLUE)Stopping development environment...$(NC)"
	docker-compose $(COMPOSE_FILES) down

dev-restart: ## Restart development environment
	@echo "$(BLUE)Restarting development environment...$(NC)"
	$(MAKE) dev-stop
	$(MAKE) dev-start

dev-logs: ## Show logs from all services
	docker-compose $(COMPOSE_FILES) logs -f --tail=100

dev-logs-api: ## Show logs from API service
	docker-compose $(COMPOSE_FILES) logs -f --tail=100 api

dev-logs-collector: ## Show logs from Collector service
	docker-compose $(COMPOSE_FILES) logs -f --tail=100 collector

dev-logs-storage: ## Show logs from Storage service
	docker-compose $(COMPOSE_FILES) logs -f --tail=100 storage

dev-clean: ## Stop and remove all containers, networks, and volumes
	@echo "$(YELLOW)WARNING: This will remove all containers, networks, and volumes.$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [ "$$REPLY" = "y" ] || [ "$$REPLY" = "Y" ]; then \
		echo "$(BLUE)Cleaning development environment...$(NC)"; \
		docker-compose $(COMPOSE_FILES) down -v; \
		docker volume prune -f; \
		echo "$(GREEN)Environment cleaned$(NC)"; \
	else \
		echo "$(BLUE)Clean cancelled$(NC)"; \
	fi

dev-rebuild: ## Rebuild all services from scratch
	@echo "$(BLUE)Rebuilding services...$(NC)"
	docker-compose $(COMPOSE_FILES) build --no-cache

dev-rebuild-api: ## Rebuild API service
	@echo "$(BLUE)Rebuilding API service...$(NC)"
	docker-compose $(COMPOSE_FILES) build --no-cache api

dev-rebuild-collector: ## Rebuild Collector service
	@echo "$(BLUE)Rebuilding Collector service...$(NC)"
	docker-compose $(COMPOSE_FILES) build --no-cache collector

dev-rebuild-storage: ## Rebuild Storage service
	@echo "$(BLUE)Rebuilding Storage service...$(NC)"
	docker-compose $(COMPOSE_FILES) build --no-cache storage

# =============================================================================
# Database Operations
# =============================================================================

dev-seed: ## Seed database with sample data
	@echo "$(BLUE)Seeding database with sample data...$(NC)"
	docker-compose $(COMPOSE_FILES) run --rm dev-utils sh -c "psql < /seed-data/seed.sql"
	@echo "$(GREEN)Database seeded$(NC)"

dev-reset: ## Reset database to clean state
	@echo "$(YELLOW)WARNING: This will delete all data in the database.$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [ "$$REPLY" = "y" ] || [ "$$REPLY" = "Y" ]; then \
		echo "$(BLUE)Resetting database...$(NC)"; \
		docker-compose $(COMPOSE_FILES) run --rm dev-utils sh -c "psql < /seed-data/reset.sql"; \
		echo "$(GREEN)Database reset$(NC)"; \
		read -p "Would you like to seed with sample data? [Y/n] " -n 1 -r; \
		echo; \
		if [ -z "$$REPLY" ] || [ "$$REPLY" = "y" ] || [ "$$REPLY" = "Y" ]; then \
			$(MAKE) dev-seed; \
		fi; \
	else \
		echo "$(BLUE)Reset cancelled$(NC)"; \
	fi

db-shell: ## Open PostgreSQL shell
	@echo "$(BLUE)Opening PostgreSQL shell...$(NC)"
	docker-compose $(COMPOSE_FILES) exec timescaledb psql -U postgres -d llm_observatory

db-backup: ## Create database backup
	@echo "$(BLUE)Creating database backup...$(NC)"
	@mkdir -p backups
	docker-compose $(COMPOSE_FILES) exec -T timescaledb pg_dump -U postgres llm_observatory > backups/backup_$$(date +%Y%m%d_%H%M%S).sql
	@echo "$(GREEN)Backup created in backups/$(NC)"

# =============================================================================
# Container Shells
# =============================================================================

dev-shell-api: ## Open shell in API container
	@echo "$(BLUE)Opening shell in API container...$(NC)"
	docker-compose $(COMPOSE_FILES) exec api sh

dev-shell-collector: ## Open shell in Collector container
	@echo "$(BLUE)Opening shell in Collector container...$(NC)"
	docker-compose $(COMPOSE_FILES) exec collector sh

dev-shell-storage: ## Open shell in Storage container
	@echo "$(BLUE)Opening shell in Storage container...$(NC)"
	docker-compose $(COMPOSE_FILES) exec storage sh

# =============================================================================
# Testing
# =============================================================================

dev-test: ## Run tests in all services
	@echo "$(BLUE)Running tests in all services...$(NC)"
	docker-compose $(COMPOSE_FILES) exec collector cargo test
	docker-compose $(COMPOSE_FILES) exec api cargo test
	docker-compose $(COMPOSE_FILES) exec storage cargo test
	@echo "$(GREEN)All tests completed$(NC)"

dev-test-api: ## Run tests in API service
	@echo "$(BLUE)Running tests in API service...$(NC)"
	docker-compose $(COMPOSE_FILES) exec api cargo test

dev-test-collector: ## Run tests in Collector service
	@echo "$(BLUE)Running tests in Collector service...$(NC)"
	docker-compose $(COMPOSE_FILES) exec collector cargo test

dev-test-storage: ## Run tests in Storage service
	@echo "$(BLUE)Running tests in Storage service...$(NC)"
	docker-compose $(COMPOSE_FILES) exec storage cargo test

# =============================================================================
# Code Quality
# =============================================================================

format: ## Format Rust code
	@echo "$(BLUE)Formatting Rust code...$(NC)"
	cargo fmt --all

format-check: ## Check Rust code formatting
	@echo "$(BLUE)Checking Rust code formatting...$(NC)"
	cargo fmt --all -- --check

lint: ## Run clippy linter
	@echo "$(BLUE)Running clippy...$(NC)"
	cargo clippy --all-targets --all-features -- -D warnings

check: ## Check code without building
	@echo "$(BLUE)Checking code...$(NC)"
	cargo check --all-targets --all-features

# =============================================================================
# Local Development (without Docker)
# =============================================================================

build: ## Build all crates locally
	@echo "$(BLUE)Building all crates...$(NC)"
	cargo build --workspace

build-release: ## Build all crates in release mode
	@echo "$(BLUE)Building all crates in release mode...$(NC)"
	cargo build --workspace --release

test: ## Run tests locally
	@echo "$(BLUE)Running tests locally...$(NC)"
	cargo test --workspace

test-verbose: ## Run tests with verbose output
	@echo "$(BLUE)Running tests with verbose output...$(NC)"
	cargo test --workspace -- --nocapture

# =============================================================================
# Documentation
# =============================================================================

doc: ## Generate and open documentation
	@echo "$(BLUE)Generating documentation...$(NC)"
	cargo doc --no-deps --open

doc-all: ## Generate documentation for all dependencies
	@echo "$(BLUE)Generating documentation (including dependencies)...$(NC)"
	cargo doc --open

# =============================================================================
# Utilities
# =============================================================================

status: ## Show status of development environment
	@echo "$(BLUE)Development environment status:$(NC)"
	@docker-compose $(COMPOSE_FILES) ps

health: ## Check health of all services
	@echo "$(BLUE)Checking service health...$(NC)"
	@echo "\n$(GREEN)API:$(NC)"
	@curl -s http://localhost:8080/health | jq '.' || echo "$(YELLOW)Not available$(NC)"
	@echo "\n$(GREEN)Storage:$(NC)"
	@curl -s http://localhost:8081/health | jq '.' || echo "$(YELLOW)Not available$(NC)"
	@echo "\n$(GREEN)Collector (HTTP):$(NC)"
	@curl -s http://localhost:9091/health || echo "$(YELLOW)Not available$(NC)"
	@echo "\n$(GREEN)Grafana:$(NC)"
	@curl -s http://localhost:3000/api/health | jq '.' || echo "$(YELLOW)Not available$(NC)"

env: ## Create .env file from example
	@if [ -f .env ]; then \
		echo "$(YELLOW).env file already exists$(NC)"; \
	else \
		echo "$(BLUE)Creating .env file from .env.example...$(NC)"; \
		cp .env.example .env; \
		echo "$(GREEN).env file created$(NC)"; \
	fi

setup: env ## Initial setup (create .env)
	@echo "$(GREEN)Setup complete! Run 'make dev-start' to start the development environment.$(NC)"

clean-cargo: ## Clean cargo build artifacts
	@echo "$(BLUE)Cleaning cargo build artifacts...$(NC)"
	cargo clean

# =============================================================================
# Quick Commands
# =============================================================================

up: dev-start ## Alias for dev-start

down: dev-stop ## Alias for dev-stop

logs: dev-logs ## Alias for dev-logs

restart: dev-restart ## Alias for dev-restart

# =============================================================================
# Testing Infrastructure
# =============================================================================

test-all: start-test-db ## Run comprehensive test suite
	@echo "$(BLUE)Running comprehensive test suite...$(NC)"
	./docker/test/run-all-tests.sh

test-unit: ## Run unit tests only
	@echo "$(BLUE)Running unit tests...$(NC)"
	cargo nextest run --workspace --lib --all-features

test-integration: start-test-db ## Run integration tests
	@echo "$(BLUE)Running integration tests...$(NC)"
	@export DATABASE_URL="postgres://test_user:test_password@localhost:5433/llm_observatory_test" && \
	export REDIS_URL="redis://:test_redis@localhost:6380" && \
	cargo nextest run --workspace --test '*' --all-features

test-coverage: start-test-db ## Generate code coverage
	@echo "$(BLUE)Generating coverage report...$(NC)"
	@export DATABASE_URL="postgres://test_user:test_password@localhost:5433/llm_observatory_test" && \
	export REDIS_URL="redis://:test_redis@localhost:6380" && \
	./docker/test/run-coverage.sh
	@echo "$(GREEN)Coverage: coverage/index.html$(NC)"

test-docker: ## Run tests in Docker
	@echo "$(BLUE)Running tests in Docker...$(NC)"
	docker compose -f docker-compose.test.yml build test-runner
	docker compose -f docker-compose.test.yml run --rm test-runner

test-parallel: ## Run parallel tests (4 shards)
	@echo "$(BLUE)Running parallel tests...$(NC)"
	@for i in 0 1 2 3; do \
		SHARD_INDEX=$$i SHARD_TOTAL=4 \
		docker compose -f docker-compose.test.yml --profile parallel-test up -d; \
	done

start-test-db: ## Start test databases
	@echo "$(BLUE)Starting test databases...$(NC)"
	docker compose -f docker-compose.test.yml up -d timescaledb-test redis-test
	@sleep 3
	@echo "$(GREEN)Test databases ready$(NC)"

stop-test-db: ## Stop test databases
	@echo "$(BLUE)Stopping test databases...$(NC)"
	docker compose -f docker-compose.test.yml down

seed-test-data: start-test-db ## Seed test database
	@echo "$(BLUE)Seeding test database...$(NC)"
	docker compose -f docker-compose.test.yml run --rm test-seeder

ci-test: ## Run CI test pipeline
	@echo "$(BLUE)Running CI test pipeline...$(NC)"
	docker compose -f docker-compose.test.yml --profile test up --build --abort-on-container-exit

ci-coverage: ## Run CI coverage pipeline
	@echo "$(BLUE)Running CI coverage pipeline...$(NC)"
	docker compose -f docker-compose.test.yml --profile coverage up --build --abort-on-container-exit

clean-test: ## Clean test artifacts
	@echo "$(BLUE)Cleaning test artifacts...$(NC)"
	docker compose -f docker-compose.test.yml down -v
	rm -rf coverage/ test-results/
