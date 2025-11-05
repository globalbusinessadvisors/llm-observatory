# Makefile for Chat API service

.PHONY: help install dev test lint format clean docker-build docker-run docker-stop

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

install: ## Install dependencies
	pip install -r requirements.txt

dev: ## Run development server
	uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

test: ## Run tests
	pytest

test-cov: ## Run tests with coverage
	pytest --cov=app --cov-report=html --cov-report=term

lint: ## Run linters
	flake8 app/ tests/
	pylint app/
	mypy app/

format: ## Format code
	black app/ tests/
	isort app/ tests/

clean: ## Clean up generated files
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name '*.pyc' -delete
	find . -type f -name '*.pyo' -delete
	find . -type d -name '*.egg-info' -exec rm -rf {} +
	rm -rf .pytest_cache
	rm -rf htmlcov
	rm -rf .coverage
	rm -rf dist
	rm -rf build

docker-build: ## Build Docker image
	docker build -t llm-observatory-chat-api:latest .

docker-run: ## Run with Docker Compose
	docker-compose up -d

docker-stop: ## Stop Docker containers
	docker-compose down

docker-logs: ## Show Docker logs
	docker-compose logs -f chat-api

docker-shell: ## Open shell in Docker container
	docker-compose exec chat-api /bin/bash

db-shell: ## Open PostgreSQL shell
	docker-compose exec timescaledb psql -U postgres -d llm_observatory

redis-cli: ## Open Redis CLI
	docker-compose exec redis redis-cli -a redis_password
