# NATS Server Docker Makefile
# Automates build, test, and deployment processes

# Variables
IMAGE_NAME ?= nats-server
IMAGE_TAG ?= latest
REGISTRY ?= ghcr.io/
GITHUB_USERNAME ?= $(shell git config user.name | tr '[:upper:]' '[:lower:]' | sed 's/ //g' | sed 's/[^a-z0-9._-]//g')
FULL_IMAGE_NAME = $(REGISTRY)$(GITHUB_USERNAME)/$(IMAGE_NAME):$(IMAGE_TAG)

# Docker Compose files
COMPOSE_FILE = docker-compose.yml
COMPOSE_DEV_FILE = docker-compose.dev.yml
COMPOSE_PROD_FILE = docker-compose.prod.yml

# Directories
CREDS_DIR = ./creds
CERTS_DIR = ./certs
JWT_DIR = ./jwt
LOGS_DIR = ./logs

# Default target
.DEFAULT_GOAL := help

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

.PHONY: help build build-dev build-prod push pull clean test run run-dev run-prod stop logs shell setup-creds setup-certs setup-jwt generate-keys deploy deploy-dev deploy-prod lint security-scan backup restore

# Help target
help: ## Show this help message
	@echo "$(BLUE)NATS Server Docker Management$(NC)"
	@echo "================================"
	@echo ""
	@echo "$(YELLOW)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make build                    # Build the Docker image"
	@echo "  make run                      # Run NATS server locally"
	@echo "  make deploy-prod              # Deploy to production"
	@echo "  make setup-creds              # Setup credentials directory"

# Build targets
build: ## Build the Docker image
	@echo "$(BLUE)Building $(FULL_IMAGE_NAME)...$(NC)"
	docker build -t $(FULL_IMAGE_NAME) .
	@echo "$(GREEN)Build completed successfully!$(NC)"

build-dev: ## Build development image with debug enabled
	@echo "$(BLUE)Building development image...$(NC)"
	docker build --build-arg BUILD_TYPE=dev -t $(IMAGE_NAME):dev .
	@echo "$(GREEN)Development build completed!$(NC)"

build-prod: ## Build production image with optimizations
	@echo "$(BLUE)Building production image...$(NC)"
	docker build --build-arg BUILD_TYPE=prod -t $(IMAGE_NAME):prod .
	@echo "$(GREEN)Production build completed!$(NC)"

# Push/Pull targets
push: ## Push image to GitHub Container Registry
	@echo "$(BLUE)Pushing $(FULL_IMAGE_NAME) to GitHub Container Registry...$(NC)"
	@if [ -z "$(GITHUB_TOKEN)" ]; then \
		echo "$(RED)GITHUB_TOKEN environment variable is required for pushing to ghcr.io$(NC)"; \
		echo "$(YELLOW)Set it with: export GITHUB_TOKEN=your_github_token$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Logging in to GitHub Container Registry...$(NC)"
	@echo "$(GITHUB_TOKEN)" | docker login ghcr.io -u $(GITHUB_USERNAME) --password-stdin
	@echo "$(YELLOW)Pushing image...$(NC)"
	docker push $(FULL_IMAGE_NAME)
	@echo "$(GREEN)Push completed!$(NC)"

push-latest: ## Push latest tag to GitHub Container Registry
	@echo "$(BLUE)Pushing latest tag to GitHub Container Registry...$(NC)"
	@if [ -z "$(GITHUB_TOKEN)" ]; then \
		echo "$(RED)GITHUB_TOKEN environment variable is required for pushing to ghcr.io$(NC)"; \
		echo "$(YELLOW)Set it with: export GITHUB_TOKEN=your_github_token$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Logging in to GitHub Container Registry...$(NC)"
	@echo "$(GITHUB_TOKEN)" | docker login ghcr.io -u $(GITHUB_USERNAME) --password-stdin
	@echo "$(YELLOW)Tagging as latest...$(NC)"
	docker tag $(FULL_IMAGE_NAME) $(REGISTRY)$(GITHUB_USERNAME)/$(IMAGE_NAME):latest
	@echo "$(YELLOW)Pushing latest tag...$(NC)"
	docker push $(REGISTRY)$(GITHUB_USERNAME)/$(IMAGE_NAME):latest
	@echo "$(GREEN)Latest tag pushed!$(NC)"

pull: ## Pull image from GitHub Container Registry
	@echo "$(BLUE)Pulling $(FULL_IMAGE_NAME) from GitHub Container Registry...$(NC)"
	docker pull $(FULL_IMAGE_NAME)
	@echo "$(GREEN)Pull completed!$(NC)"

login-ghcr: ## Login to GitHub Container Registry
	@echo "$(BLUE)Logging in to GitHub Container Registry...$(NC)"
	@if [ -z "$(GITHUB_TOKEN)" ]; then \
		echo "$(RED)GITHUB_TOKEN environment variable is required$(NC)"; \
		echo "$(YELLOW)Set it with: export GITHUB_TOKEN=your_github_token$(NC)"; \
		exit 1; \
	fi
	@echo "$(GITHUB_TOKEN)" | docker login ghcr.io -u $(GITHUB_USERNAME) --password-stdin
	@echo "$(GREEN)Login successful!$(NC)"

# Cleanup targets
clean: ## Remove containers, images, and volumes
	@echo "$(YELLOW)Cleaning up Docker resources...$(NC)"
	docker-compose down -v --remove-orphans
	docker system prune -f
	docker volume prune -f
	@echo "$(GREEN)Cleanup completed!$(NC)"

clean-images: ## Remove all NATS server images
	@echo "$(YELLOW)Removing NATS server images...$(NC)"
	docker images | grep $(IMAGE_NAME) | awk '{print $$3}' | xargs -r docker rmi -f
	@echo "$(GREEN)Images removed!$(NC)"

# Test targets
test: ## Run tests on the built image
	@echo "$(BLUE)Running tests...$(NC)"
	@echo "$(YELLOW)Testing image build...$(NC)"
	docker run --rm $(FULL_IMAGE_NAME) nats-server --version
	@echo "$(YELLOW)Testing health check...$(NC)"
	docker run -d --name test-nats $(FULL_IMAGE_NAME)
	@sleep 5
	@docker exec test-nats wget --no-verbose --tries=1 --spider http://localhost:8222/healthz || (echo "$(RED)Health check failed!$(NC)" && exit 1)
	@docker stop test-nats && docker rm test-nats
	@echo "$(GREEN)All tests passed!$(NC)"

# Run targets
run: ## Run NATS server using docker-compose
	@echo "$(BLUE)Starting NATS server...$(NC)"
	docker-compose up -d
	@echo "$(GREEN)NATS server started!$(NC)"
	@echo "$(YELLOW)Monitor at: http://localhost:8222$(NC)"

run-dev: ## Run in development mode with debug
	@echo "$(BLUE)Starting NATS server in development mode...$(NC)"
	IMAGE_TAG=dev docker-compose -f $(COMPOSE_DEV_FILE) up -d
	@echo "$(GREEN)Development server started!$(NC)"

run-prod: ## Run in production mode
	@echo "$(BLUE)Starting NATS server in production mode...$(NC)"
	IMAGE_TAG=prod docker-compose -f $(COMPOSE_PROD_FILE) up -d
	@echo "$(GREEN)Production server started!$(NC)"

stop: ## Stop NATS server
	@echo "$(YELLOW)Stopping NATS server...$(NC)"
	docker-compose down
	@echo "$(GREEN)Server stopped!$(NC)"

# Logs and monitoring
logs: ## Show NATS server logs
	@echo "$(BLUE)Showing NATS server logs...$(NC)"
	docker-compose logs -f nats-server

logs-tail: ## Show last 100 lines of logs
	@echo "$(BLUE)Showing last 100 lines of logs...$(NC)"
	docker-compose logs --tail=100 nats-server

# Shell access
shell: ## Access shell in running container
	@echo "$(BLUE)Accessing shell in NATS server container...$(NC)"
	docker-compose exec nats-server /bin/sh

# Setup targets
setup-creds: ## Setup credentials directory structure
	@echo "$(BLUE)Setting up credentials directory...$(NC)"
	mkdir -p $(CREDS_DIR)
	chmod 700 $(CREDS_DIR)
	@echo "$(GREEN)Credentials directory created at $(CREDS_DIR)$(NC)"
	@echo "$(YELLOW)Place your credential files in $(CREDS_DIR)$(NC)"

setup-certs: ## Setup certificates directory structure
	@echo "$(BLUE)Setting up certificates directory...$(NC)"
	mkdir -p $(CERTS_DIR)
	chmod 700 $(CERTS_DIR)
	@echo "$(GREEN)Certificates directory created at $(CERTS_DIR)$(NC)"
	@echo "$(YELLOW)Place your TLS certificates in $(CERTS_DIR)$(NC)"

setup-jwt: ## Setup JWT directory structure
	@echo "$(BLUE)Setting up JWT directory...$(NC)"
	mkdir -p $(JWT_DIR)
	chmod 700 $(JWT_DIR)
	@echo "$(GREEN)JWT directory created at $(JWT_DIR)$(NC)"
	@echo "$(YELLOW)Place your JWT files in $(JWT_DIR)$(NC)"

setup-all: setup-creds setup-certs setup-jwt ## Setup all directories
	@echo "$(GREEN)All directories setup completed!$(NC)"

# Key generation
generate-keys: ## Generate NKeys for authentication
	@echo "$(BLUE)Generating NKeys...$(NC)"
	@if ! command -v nats &> /dev/null; then \
		echo "$(RED)NATS CLI not found. Installing...$(NC)"; \
		go install github.com/nats-io/natscli/nats@latest; \
	fi
	@echo "$(YELLOW)Generating operator key...$(NC)"
	nats operator generate --output-file $(CREDS_DIR)/operator.nk
	@echo "$(YELLOW)Generating account key...$(NC)"
	nats account generate --output-file $(CREDS_DIR)/account.nk
	@echo "$(YELLOW)Generating user key...$(NC)"
	nats user generate --output-file $(CREDS_DIR)/user.nk
	@echo "$(GREEN)NKeys generated in $(CREDS_DIR)$(NC)"

# Deployment targets
deploy: ## Deploy to default environment
	@echo "$(BLUE)Deploying NATS server...$(NC)"
	make build
	make run
	@echo "$(GREEN)Deployment completed!$(NC)"

deploy-dev: ## Deploy to development environment
	@echo "$(BLUE)Deploying to development...$(NC)"
	make build-dev
	make run-dev
	@echo "$(GREEN)Development deployment completed!$(NC)"

deploy-prod: ## Deploy to production environment
	@echo "$(BLUE)Deploying to production...$(NC)"
	make build-prod
	make run-prod
	@echo "$(GREEN)Production deployment completed!$(NC)"

# Release targets
release: build push push-latest ## Build and release to GitHub Container Registry
	@echo "$(GREEN)Release completed!$(NC)"

release-dev: build-dev ## Build and release development version
	@echo "$(BLUE)Releasing development version...$(NC)"
	@if [ -z "$(GITHUB_TOKEN)" ]; then \
		echo "$(RED)GITHUB_TOKEN environment variable is required$(NC)"; \
		exit 1; \
	fi
	@echo "$(GITHUB_TOKEN)" | docker login ghcr.io -u $(GITHUB_USERNAME) --password-stdin
	docker tag $(IMAGE_NAME):dev $(REGISTRY)$(GITHUB_USERNAME)/$(IMAGE_NAME):dev
	docker push $(REGISTRY)$(GITHUB_USERNAME)/$(IMAGE_NAME):dev
	@echo "$(GREEN)Development release completed!$(NC)"

release-prod: build-prod ## Build and release production version
	@echo "$(BLUE)Releasing production version...$(NC)"
	@if [ -z "$(GITHUB_TOKEN)" ]; then \
		echo "$(RED)GITHUB_TOKEN environment variable is required$(NC)"; \
		exit 1; \
	fi
	@echo "$(GITHUB_TOKEN)" | docker login ghcr.io -u $(GITHUB_USERNAME) --password-stdin
	docker tag $(IMAGE_NAME):prod $(REGISTRY)$(GITHUB_USERNAME)/$(IMAGE_NAME):prod
	docker push $(REGISTRY)$(GITHUB_USERNAME)/$(IMAGE_NAME):prod
	@echo "$(GREEN)Production release completed!$(NC)"

# Security and quality targets
lint: ## Lint Dockerfile and configuration
	@echo "$(BLUE)Linting Dockerfile...$(NC)"
	@if command -v hadolint &> /dev/null; then \
		hadolint Dockerfile; \
	else \
		echo "$(YELLOW)hadolint not found. Install with: brew install hadolint$(NC)"; \
	fi
	@echo "$(GREEN)Linting completed!$(NC)"

security-scan: ## Run security scan on image
	@echo "$(BLUE)Running security scan...$(NC)"
	@if command -v trivy &> /dev/null; then \
		trivy image $(FULL_IMAGE_NAME); \
	else \
		echo "$(YELLOW)trivy not found. Install with: brew install trivy$(NC)"; \
	fi

# Backup and restore
backup: ## Backup NATS data and configuration
	@echo "$(BLUE)Creating backup...$(NC)"
	mkdir -p backup/$(shell date +%Y%m%d_%H%M%S)
	cp -r $(CREDS_DIR) backup/$(shell date +%Y%m%d_%H%M%S)/ 2>/dev/null || true
	cp -r $(CERTS_DIR) backup/$(shell date +%Y%m%d_%H%M%S)/ 2>/dev/null || true
	cp -r $(JWT_DIR) backup/$(shell date +%Y%m%d_%H%M%S)/ 2>/dev/null || true
	cp nats-server.conf backup/$(shell date +%Y%m%d_%H%M%S)/
	docker-compose exec nats-server tar czf /tmp/nats-data-backup.tar.gz -C /var/lib/nats . 2>/dev/null || true
	docker cp nats-server:/tmp/nats-data-backup.tar.gz backup/$(shell date +%Y%m%d_%H%M%S)/
	@echo "$(GREEN)Backup created in backup/$(shell date +%Y%m%d_%H%M%S)$(NC)"

restore: ## Restore from backup (specify BACKUP_DIR)
	@if [ -z "$(BACKUP_DIR)" ]; then \
		echo "$(RED)Please specify BACKUP_DIR=path/to/backup$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)Restoring from $(BACKUP_DIR)...$(NC)"
	cp -r $(BACKUP_DIR)/creds . 2>/dev/null || true
	cp -r $(BACKUP_DIR)/certs . 2>/dev/null || true
	cp -r $(BACKUP_DIR)/jwt . 2>/dev/null || true
	cp $(BACKUP_DIR)/nats-server.conf . 2>/dev/null || true
	@echo "$(GREEN)Restore completed!$(NC)"

# Status and info
status: ## Show status of NATS server
	@echo "$(BLUE)NATS Server Status:$(NC)"
	@docker-compose ps
	@echo ""
	@echo "$(BLUE)Container logs (last 10 lines):$(NC)"
	@docker-compose logs --tail=10 nats-server
	@echo ""
	@echo "$(BLUE)Health check:$(NC)"
	@curl -s http://localhost:8222/healthz || echo "$(RED)Health check failed$(NC)"

info: ## Show system information
	@echo "$(BLUE)System Information:$(NC)"
	@echo "Image: $(FULL_IMAGE_NAME)"
	@echo "Docker version: $(shell docker --version)"
	@echo "Docker Compose version: $(shell docker-compose --version)"
	@echo "Available memory: $(shell free -h | grep Mem | awk '{print $$2}')"
	@echo "Available disk space: $(shell df -h . | tail -1 | awk '{print $$4}')"

# Development helpers
dev-setup: setup-all generate-keys ## Complete development setup
	@echo "$(GREEN)Development environment setup completed!$(NC)"
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. Review generated keys in $(CREDS_DIR)"
	@echo "  2. Update nats-server.conf with your authentication method"
	@echo "  3. Run 'make run' to start the server"

# Production helpers
prod-setup: setup-all ## Complete production setup
	@echo "$(GREEN)Production environment setup completed!$(NC)"
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. Add your production certificates to $(CERTS_DIR)"
	@echo "  2. Configure authentication in nats-server.conf"
	@echo "  3. Run 'make deploy-prod' to deploy"

# Utility targets
version: ## Show NATS server version
	@docker run --rm $(FULL_IMAGE_NAME) nats-server --version

config-check: ## Validate NATS server configuration
	@echo "$(BLUE)Validating configuration...$(NC)"
	@docker run --rm -v $(PWD)/nats-server.conf:/etc/nats/nats-server.conf $(FULL_IMAGE_NAME) nats-server --config /etc/nats/nats-server.conf --test-config
	@echo "$(GREEN)Configuration is valid!$(NC)"

# Quick commands
quick-start: build run ## Quick start: build and run
	@echo "$(GREEN)Quick start completed!$(NC)"

quick-stop: stop clean-images ## Quick stop: stop and clean images
	@echo "$(GREEN)Quick stop completed!$(NC)"

quick-release: build push ## Quick release: build and push to ghcr.io
	@echo "$(GREEN)Quick release completed!$(NC)"
