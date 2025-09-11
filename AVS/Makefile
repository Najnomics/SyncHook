.PHONY: build run test clean docker-build docker-run help

# Variables
BINARY_NAME=synchook-operator
DOCKER_IMAGE=synchook-operator
VERSION=$(shell git describe --tags --always --dirty)
COMMIT=$(shell git rev-parse HEAD)

# Build flags
LDFLAGS=-ldflags "-X main.version=$(VERSION) -X main.commit=$(COMMIT)"

# Default target
all: build

# Build the binary
build:
	@echo "Building $(BINARY_NAME)..."
	go build $(LDFLAGS) -o $(BINARY_NAME) ./cmd/operator

# Run the application
run: build
	@echo "Running $(BINARY_NAME)..."
	./$(BINARY_NAME) start --config config.yaml

# Run tests
test:
	@echo "Running tests..."
	go test -v ./...

# Run tests with coverage
test-coverage:
	@echo "Running tests with coverage..."
	go test -v -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html

# Clean build artifacts
clean:
	@echo "Cleaning..."
	rm -f $(BINARY_NAME)
	rm -f coverage.out coverage.html

# Build Docker image
docker-build:
	@echo "Building Docker image..."
	docker build -t $(DOCKER_IMAGE):$(VERSION) .
	docker tag $(DOCKER_IMAGE):$(VERSION) $(DOCKER_IMAGE):latest

# Run with Docker Compose
docker-run:
	@echo "Starting services with Docker Compose..."
	docker-compose up -d

# Stop Docker Compose services
docker-stop:
	@echo "Stopping Docker Compose services..."
	docker-compose down

# View logs
docker-logs:
	@echo "Viewing logs..."
	docker-compose logs -f

# Install dependencies
deps:
	@echo "Installing dependencies..."
	go mod download
	go mod tidy

# Format code
fmt:
	@echo "Formatting code..."
	go fmt ./...

# Lint code
lint:
	@echo "Linting code..."
	golangci-lint run

# Generate mocks
mocks:
	@echo "Generating mocks..."
	go generate ./...

# Help
help:
	@echo "Available targets:"
	@echo "  build          - Build the binary"
	@echo "  run            - Build and run the application"
	@echo "  test           - Run tests"
	@echo "  test-coverage  - Run tests with coverage report"
	@echo "  clean          - Clean build artifacts"
	@echo "  docker-build   - Build Docker image"
	@echo "  docker-run     - Start services with Docker Compose"
	@echo "  docker-stop    - Stop Docker Compose services"
	@echo "  docker-logs    - View Docker Compose logs"
	@echo "  deps           - Install dependencies"
	@echo "  fmt            - Format code"
	@echo "  lint           - Lint code"
	@echo "  mocks          - Generate mocks"
	@echo "  help           - Show this help message"