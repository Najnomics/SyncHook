# ============================================================================
# SyncHook AVS Makefile
# Cross-chain liquidity synchronization service using EigenLayer AVS
# ============================================================================

GO = $(shell which go)
OUT = ./bin
CONTRACTS_DIR = ./contracts

# ============================================================================
# BUILD TARGETS
# ============================================================================

.PHONY: build build-contracts build-all clean

build: deps
	@mkdir -p $(OUT) || true
	@echo "Building SyncHook AVS binaries..."
	$(GO) build -o $(OUT)/synchook-operator ./cmd/operator/main.go
	$(GO) build -o $(OUT)/synchook-aggregator ./cmd/aggregator/main.go
	@echo "Build completed successfully!"

build-contracts:
	@echo "Building SyncHook contracts..."
	cd $(CONTRACTS_DIR) && forge build
	@echo "Contract build completed!"

build-all: build build-contracts
	@echo "All builds completed successfully!"

clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(OUT)
	cd $(CONTRACTS_DIR) && forge clean
	@echo "Clean completed!"

# ============================================================================
# DEPENDENCY MANAGEMENT
# ============================================================================

.PHONY: deps deps-update

deps:
	@echo "Installing Go dependencies..."
	GOPRIVATE=github.com/Layr-Labs/* $(GO) mod tidy
	GOPRIVATE=github.com/Layr-Labs/* $(GO) mod download
	@echo "Dependencies installed!"

deps-update:
	@echo "Updating Go dependencies..."
	GOPRIVATE=github.com/Layr-Labs/* $(GO) get -u ./...
	GOPRIVATE=github.com/Layr-Labs/* $(GO) mod tidy
	@echo "Dependencies updated!"

# ============================================================================
# TESTING
# ============================================================================

.PHONY: test test-go test-contracts test-coverage

test: test-go test-contracts
	@echo "All tests completed!"

test-go:
	@echo "Running Go tests..."
	$(GO) test ./... -v -p 1 -race
	@echo "Go tests completed!"

test-contracts:
	@echo "Running contract tests..."
	cd $(CONTRACTS_DIR) && forge test -vv
	@echo "Contract tests completed!"

test-coverage:
	@echo "Running tests with coverage..."
	$(GO) test ./... -v -p 1 -race -coverprofile=coverage.out
	$(GO) tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report generated: coverage.html"

# ============================================================================
# LINTING AND FORMATTING
# ============================================================================

.PHONY: lint fmt vet

lint:
	@echo "Running linters..."
	golangci-lint run
	cd $(CONTRACTS_DIR) && forge fmt --check
	@echo "Linting completed!"

fmt:
	@echo "Formatting code..."
	$(GO) fmt ./...
	cd $(CONTRACTS_DIR) && forge fmt
	@echo "Code formatted!"

vet:
	@echo "Running go vet..."
	$(GO) vet ./...
	@echo "Vet completed!"

# ============================================================================
# DOCKER OPERATIONS
# ============================================================================

.PHONY: docker-build docker-run docker-stop docker-logs

docker-build:
	@echo "Building Docker images..."
	docker build -t synchook-operator -f Dockerfile.operator .
	docker build -t synchook-aggregator -f Dockerfile.aggregator .
	@echo "Docker images built!"

docker-run:
	@echo "Starting Docker containers..."
	docker-compose up -d
	@echo "Containers started!"

docker-stop:
	@echo "Stopping Docker containers..."
	docker-compose down
	@echo "Containers stopped!"

docker-logs:
	@echo "Showing Docker logs..."
	docker-compose logs -f

# ============================================================================
# DEVELOPMENT
# ============================================================================

.PHONY: dev dev-operator dev-aggregator

dev: dev-operator
	@echo "Development environment started!"

dev-operator:
	@echo "Starting operator in development mode..."
	$(GO) run ./cmd/operator/main.go start --config config.yaml

dev-aggregator:
	@echo "Starting aggregator in development mode..."
	$(GO) run ./cmd/aggregator/main.go start --config config.yaml

# ============================================================================
# DEPLOYMENT
# ============================================================================

.PHONY: deploy-local deploy-testnet deploy-mainnet

deploy-local:
	@echo "Deploying to local network..."
	cd $(CONTRACTS_DIR) && forge script script/DeployMyL1Contracts.s.sol --rpc-url http://localhost:8545 --broadcast
	cd $(CONTRACTS_DIR) && forge script script/DeployMyL2Contracts.s.sol --rpc-url http://localhost:8545 --broadcast

deploy-testnet:
	@echo "Deploying to testnet..."
	cd $(CONTRACTS_DIR) && forge script script/DeployMyL1Contracts.s.sol --rpc-url $(TESTNET_RPC) --broadcast --verify
	cd $(CONTRACTS_DIR) && forge script script/DeployMyL2Contracts.s.sol --rpc-url $(TESTNET_RPC) --broadcast --verify

deploy-mainnet:
	@echo "Deploying to mainnet..."
	cd $(CONTRACTS_DIR) && forge script script/DeployMyL1Contracts.s.sol --rpc-url $(MAINNET_RPC) --broadcast --verify
	cd $(CONTRACTS_DIR) && forge script script/DeployMyL2Contracts.s.sol --rpc-url $(MAINNET_RPC) --broadcast --verify

# ============================================================================
# MONITORING
# ============================================================================

.PHONY: monitor logs

monitor:
	@echo "Starting monitoring..."
	$(GO) run ./cmd/operator/main.go monitor --config config.yaml

logs:
	@echo "Showing logs..."
	tail -f logs/synchook-operator.log

# ============================================================================
# HELP
# ============================================================================

.PHONY: help

help:
	@echo "SyncHook AVS Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  build          - Build Go binaries"
	@echo "  build-contracts- Build Solidity contracts"
	@echo "  build-all      - Build everything"
	@echo "  clean          - Clean build artifacts"
	@echo "  deps           - Install dependencies"
	@echo "  test           - Run all tests"
	@echo "  test-go        - Run Go tests"
	@echo "  test-contracts - Run contract tests"
	@echo "  lint           - Run linters"
	@echo "  fmt            - Format code"
	@echo "  docker-build   - Build Docker images"
	@echo "  docker-run     - Start Docker containers"
	@echo "  dev            - Start development environment"
	@echo "  deploy-local   - Deploy to local network"
	@echo "  deploy-testnet - Deploy to testnet"
	@echo "  deploy-mainnet - Deploy to mainnet"
	@echo "  help           - Show this help message"
