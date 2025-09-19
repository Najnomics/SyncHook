# ============================================================================
# SyncHook AVS Dockerfile
# Cross-chain liquidity synchronization service using EigenLayer AVS
# ============================================================================

FROM golang:1.21-alpine AS build

# Set working directory
WORKDIR /build

# Install build dependencies
RUN apk add --no-cache git make gcc musl-dev

# Copy go mod files first for better caching
COPY go.mod go.sum ./

# Download dependencies
RUN GOPRIVATE=github.com/Layr-Labs/* go mod download

# Copy source code
COPY . .

# Build the application
RUN make build

# ============================================================================
# Final stage
# ============================================================================
FROM alpine:latest

# Install runtime dependencies
RUN apk --no-cache add ca-certificates tzdata wget

# Create non-root user
RUN adduser -D -s /bin/sh synchook

# Set working directory
WORKDIR /app

# Copy the binaries from build stage
COPY --from=build /build/bin/synchook-operator /usr/local/bin/synchook-operator
COPY --from=build /build/bin/synchook-aggregator /usr/local/bin/synchook-aggregator

# Copy configuration files
COPY config.yaml.example ./config.yaml

# Change ownership to non-root user
RUN chown -R synchook:synchook /app

# Switch to non-root user
USER synchook

# Expose ports
EXPOSE 8080 9090

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Run the operator
CMD ["/usr/local/bin/synchook-operator", "start", "--config", "config.yaml"]
