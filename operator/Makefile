# SyncHook AVS Operator Makefile

.PHONY: build clean test run-operator run-aggregator install deps

# Build configuration
BINARY_DIR = bin
OPERATOR_BINARY = $(BINARY_DIR)/operator
AGGREGATOR_BINARY = $(BINARY_DIR)/aggregator
GO_VERSION = 1.21

# Default target
all: build

# Build binaries
build: deps
	@echo "Building SyncHook AVS Operator..."
	@mkdir -p $(BINARY_DIR)
	@go build -ldflags "-X main.version=$(shell git describe --tags --always --dirty)" -o $(OPERATOR_BINARY) ./cmd/operator
	@go build -ldflags "-X main.version=$(shell git describe --tags --always --dirty)" -o $(AGGREGATOR_BINARY) ./cmd/aggregator
	@echo "Build complete!"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BINARY_DIR)
	@go clean

# Install dependencies
deps:
	@echo "Installing dependencies..."
	@go mod download
	@go mod tidy

# Run tests
test:
	@echo "Running tests..."
	@go test -v ./...

# Run tests with coverage
test-coverage:
	@echo "Running tests with coverage..."
	@go test -v -coverprofile=coverage.out ./...
	@go tool cover -html=coverage.out -o coverage.html

# Run operator
run-operator: build
	@echo "Starting SyncHook Operator..."
	@$(OPERATOR_BINARY) --config config/operator.yaml

# Run aggregator
run-aggregator: build
	@echo "Starting SyncHook Aggregator..."
	@$(AGGREGATOR_BINARY) --config config/aggregator.yaml

# Run both operator and aggregator
run: build
	@echo "Starting SyncHook AVS System..."
	@$(AGGREGATOR_BINARY) --config config/aggregator.yaml &
	@sleep 2
	@$(OPERATOR_BINARY) --config config/operator.yaml

# Generate keys
generate-keys:
	@echo "Generating operator keys..."
	@mkdir -p keys
	@echo "ECDSA key generation (implement key conversion utility)"
	@echo "BLS key generation (use EigenLayer tools)"

# Format code
fmt:
	@echo "Formatting code..."
	@go fmt ./...

# Lint code
lint:
	@echo "Linting code..."
	@golangci-lint run

# Security scan
security:
	@echo "Running security scan..."
	@gosec ./...

# Install tools
install-tools:
	@echo "Installing development tools..."
	@go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest

# Docker build
docker-build:
	@echo "Building Docker images..."
	@docker build -t synchook-operator:latest -f Dockerfile.operator .
	@docker build -t synchook-aggregator:latest -f Dockerfile.aggregator .

# Docker run
docker-run:
	@echo "Running with Docker Compose..."
	@docker-compose up -d

# Stop Docker
docker-stop:
	@echo "Stopping Docker containers..."
	@docker-compose down

# Development setup
dev-setup: install-tools deps generate-keys
	@echo "Development setup complete!"
	@echo "Next steps:"
	@echo "1. Edit config/operator.yaml with your settings"
	@echo "2. Edit config/aggregator.yaml with your settings"
	@echo "3. Run 'make run' to start the system"

# Help
help:
	@echo "Available targets:"
	@echo "  build          - Build the operator and aggregator binaries"
	@echo "  clean          - Clean build artifacts"
	@echo "  test           - Run tests"
	@echo "  test-coverage  - Run tests with coverage report"
	@echo "  run-operator   - Run the operator"
	@echo "  run-aggregator - Run the aggregator"
	@echo "  run            - Run both operator and aggregator"
	@echo "  generate-keys  - Generate operator keys"
	@echo "  fmt            - Format code"
	@echo "  lint           - Lint code"
	@echo "  security       - Run security scan"
	@echo "  install-tools  - Install development tools"
	@echo "  docker-build   - Build Docker images"
	@echo "  docker-run     - Run with Docker Compose"
	@echo "  docker-stop    - Stop Docker containers"
	@echo "  dev-setup      - Complete development setup"
	@echo "  help           - Show this help message"
