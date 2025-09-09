# SyncHook Makefile
# Cross-chain liquidity synchronization with EigenLayer AVS and Across Protocol

.PHONY: build test coverage deploy clean install-deps format lint

# ============================================================================
# BUILD COMMANDS
# ============================================================================

build:
	forge build

clean:
	forge clean

install-deps:
	forge install foundry-rs/forge-std
	forge install OpenZeppelin/openzeppelin-contracts
	forge install Layr-Labs/eigenlayer-contracts
	forge install Uniswap/v4-periphery
	forge install Layr-Labs/eigenlayer-middleware
	forge install across-protocol/contracts

# ============================================================================
# TESTING COMMANDS
# ============================================================================

test:
	forge test -vv

test-unit:
	forge test --match-path "test/unit/**/*.sol" -vv

test-integration:
	forge test --match-path "test/integration/**/*.sol" -vv

test-fuzz:
	forge test --match-path "test/fuzz/**/*.sol" -vv

test-invariant:
	forge test --match-path "test/invariant/**/*.sol" -vv

test-avs:
	forge test --match-contract "*AVS*" -vv

test-crosschain:
	forge test --match-contract "*CrossChain*" -vv

test-rebalancing:
	forge test --match-contract "*Rebalancing*" -vv

coverage:
	forge coverage --report lcov

gas-report:
	forge test --gas-report

# ============================================================================
# DEPLOYMENT COMMANDS
# ============================================================================

deploy-local:
	forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

deploy-testnet:
	forge script script/Deploy.s.sol --rpc-url $(TESTNET_RPC) --broadcast --verify

deploy-mainnet:
	forge script script/Deploy.s.sol --rpc-url $(MAINNET_RPC) --broadcast --verify

setup-avs:
	forge script script/SetupAVS.s.sol --rpc-url $(RPC_URL) --broadcast

register-operator:
	forge script script/RegisterOperator.s.sol --rpc-url $(RPC_URL) --broadcast

configure-chains:
	forge script script/ConfigureChains.s.sol --rpc-url $(RPC_URL) --broadcast

# ============================================================================
# OPTIMIZATION COMMANDS
# ============================================================================

optimize:
	forge build --optimize --optimizer-runs 10000

benchmark-state:
	forge test --match-contract "*StateCalculations*" --gas-report

benchmark-rebalancing:
	forge test --match-contract "*Rebalancing*" --gas-report

# ============================================================================
# CODE QUALITY COMMANDS
# ============================================================================

format:
	forge fmt

lint:
	forge fmt --check

# ============================================================================
# OPERATOR COMMANDS
# ============================================================================

build-operator:
	cd operator && go build -o bin/operator cmd/operator/main.go

run-operator:
	cd operator && ./bin/operator

test-operator:
	cd operator && go test ./...

# ============================================================================
# DEVELOPMENT WORKFLOW
# ============================================================================

setup: install-deps build test

dev: clean build test coverage

ci: format lint build test coverage gas-report