# -----------------------------------------------------------------------------
# This Makefile is used for building your AVS application.
#
# It contains basic targets for building the application, installing dependencies,
# and building a Docker container.
#
# Modify each target as needed to suit your application's requirements.
# -----------------------------------------------------------------------------

GO = $(shell which go)
OUT = ./bin

build: deps
	@mkdir -p $(OUT) || true
	@echo "Building SyncHook binaries..."
	go build -o $(OUT)/synchook-performer ./cmd/main.go
	go build -o $(OUT)/synchook-aggregator ./cmd/aggregator/main.go
	go build -o $(OUT)/synchook-operator ./cmd/operator/main.go

build-contracts:
	@echo "Building contracts..."
	cd .devkit/contracts && forge build

deps:
	GOPRIVATE=github.com/Layr-Labs/* go mod tidy

build/container:
	./.hourglass/scripts/buildContainer.sh

test: test-go test-forge

test-go::
	go test ./... -v -p 1

test-forge:
	cd .devkit/contracts && forge test
