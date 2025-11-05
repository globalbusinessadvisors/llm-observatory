.PHONY: help build run test clean docker-build docker-run lint format check

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

build: ## Build the analytics API service
	cargo build --release

run: ## Run the analytics API service in development mode
	cargo run

test: ## Run all tests
	cargo test

test-integration: ## Run integration tests (requires database)
	cargo test --test integration_tests -- --ignored

clean: ## Clean build artifacts
	cargo clean

docker-build: ## Build Docker image
	docker build -t llm-observatory/analytics-api:latest .

docker-run: ## Run Docker container
	docker run -d \
		-p 8080:8080 \
		-p 9091:9091 \
		--env-file ../../.env \
		--name analytics-api \
		llm-observatory/analytics-api:latest

docker-stop: ## Stop Docker container
	docker stop analytics-api || true
	docker rm analytics-api || true

lint: ## Run linter
	cargo clippy -- -D warnings

format: ## Format code
	cargo fmt

check: ## Check code without building
	cargo check

watch: ## Watch for changes and rebuild
	cargo watch -x run

dev: ## Run in development mode with auto-reload
	RUST_LOG=debug cargo watch -x run

# Database commands
db-setup: ## Setup test database
	@echo "Creating test database..."
	psql -h localhost -U postgres -c "CREATE DATABASE llm_observatory_test;" || true

db-migrate: ## Run migrations on test database
	@echo "Running migrations..."
	DATABASE_URL=postgresql://postgres:postgres@localhost:5432/llm_observatory_test \
		sqlx migrate run --source ../../crates/storage/migrations

# Documentation
docs: ## Generate and open documentation
	cargo doc --no-deps --open

# CI/CD
ci: lint check test ## Run CI pipeline
	@echo "CI pipeline complete!"
