# Multi-stage build for SyncHook Operator
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git make

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the operator
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o bin/operator ./cmd/operator

# Build the aggregator
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o bin/aggregator ./cmd/aggregator

# Final stage
FROM alpine:latest

# Install ca-certificates for HTTPS requests
RUN apk --no-cache add ca-certificates tzdata

# Create non-root user
RUN adduser -D -s /bin/sh synchook

# Set working directory
WORKDIR /app

# Copy binaries from builder stage
COPY --from=builder /app/bin/operator .
COPY --from=builder /app/bin/aggregator .

# Copy configuration files
COPY --from=builder /app/config ./config

# Create directories for keys and logs
RUN mkdir -p keys logs data

# Change ownership to non-root user
RUN chown -R synchook:synchook /app

# Switch to non-root user
USER synchook

# Expose ports
EXPOSE 8090 8080 9090 9091

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:9091/health || exit 1

# Run the operator by default
CMD ["./operator", "--config", "config/operator.yaml"]
