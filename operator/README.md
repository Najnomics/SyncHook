# SyncHook AVS Operator

This is the Go-based AVS operator for SyncHook, responsible for state aggregation, validation, predictive analytics, and cross-chain rebalancing coordination.

## Architecture

The operator consists of several key components:

- **Operator**: Main operator that handles EigenLayer integration and task processing
- **Aggregator**: State aggregation and consensus mechanism
- **State Management**: Pool state tracking, validation, and prediction
- **Across Integration**: Cross-chain liquidity rebalancing
- **Blockchain Clients**: Multi-chain connectivity and data retrieval
- **Monitoring**: Performance metrics, alerts, and health checks

## Directory Structure

```
operator/
├── cmd/
│   ├── operator/          # Main operator entry point
│   └── aggregator/        # Aggregator entry point
├── pkg/
│   ├── eigenlayer/        # EigenLayer integration
│   ├── state/             # State management (aggregation, validation, prediction)
│   ├── across/            # Across Protocol integration
│   ├── blockchain/        # Multi-chain blockchain clients
│   └── monitoring/        # Monitoring and metrics
├── config/                # Configuration files
├── keys/                  # Operator keys (generated)
└── go.mod                 # Go module definition
```

## Features

### State Management
- **Real-time Aggregation**: Collects pool state from multiple chains
- **Consensus Validation**: Ensures data integrity across operators
- **Predictive Analytics**: AI-driven price and liquidity predictions
- **Imbalance Detection**: Identifies when rebalancing is needed

### Cross-Chain Operations
- **Multi-Chain Support**: Ethereum, Arbitrum, Polygon, Optimism, Base
- **Liquidity Rebalancing**: Automated cross-chain liquidity movement
- **Cost Optimization**: Efficient routing through Across Protocol
- **Transaction Monitoring**: Real-time status tracking

### Monitoring & Alerts
- **Performance Metrics**: Prometheus-based monitoring
- **Health Checks**: System health and uptime tracking
- **Alert System**: Real-time notifications for issues
- **Dashboard**: Web-based monitoring interface

## Configuration

### Operator Configuration (`config/operator.yaml`)

```yaml
# Operator Identity
ecdsa_private_key_store_path: "./keys/operator.ecdsa.key.json"
bls_private_key_store_path: "./keys/operator.bls.key.json"

# Ethereum Configuration
eth_rpc_url: "http://localhost:8545"
eth_ws_url: "ws://localhost:8546"

# EigenLayer Configuration
registry_coordinator_address: "0x..."
operator_state_retriever_address: "0x..."
aggregator_server_ip_port_address: "localhost:8090"

# SyncHook Configuration
sync_avs_address: "0x..."
across_address: "0x..."

# Supported Chains
supported_chains:
  - chain_id: 1
    name: "Ethereum"
    rpc_url: "http://localhost:8545"
    block_time: 12
    gas_price: 20000000000
  # ... more chains

# State Management
state_update_interval: 30
rebalancing_threshold: 0.05
max_rebalancing_amount: "1000000000000000000000000"
```

### Aggregator Configuration (`config/aggregator.yaml`)

```yaml
# Server Configuration
server_ip_port_address: "localhost:8090"
enable_grpc: true
enable_http: true

# Task Management
task_timeout: 300
max_concurrent_tasks: 100
state_validation_threshold: 0.8

# Rebalancing
rebalancing_enabled: true
rebalancing_threshold: 0.05
max_rebalancing_amount: "1000000000000000000000000"
```

## Installation

### Prerequisites

- Go 1.21+
- Ethereum node access
- EigenLayer AVS registration

### Setup

1. **Clone and build**:
```bash
cd operator
go mod tidy
go build -o bin/operator ./cmd/operator
go build -o bin/aggregator ./cmd/aggregator
```

2. **Generate keys**:
```bash
# Generate ECDSA key
openssl ecparam -genkey -name secp256k1 -noout -out keys/operator.ecdsa.key.pem
# Convert to JSON format (implement key conversion utility)

# Generate BLS key
# Use EigenLayer key generation tools
```

3. **Configure**:
```bash
# Edit configuration files
cp config/operator.yaml.example config/operator.yaml
cp config/aggregator.yaml.example config/aggregator.yaml
```

4. **Run**:
```bash
# Start aggregator
./bin/aggregator --config config/aggregator.yaml

# Start operator
./bin/operator --config config/operator.yaml
```

## Usage

### Starting the Operator

```bash
# With default config
./bin/operator

# With custom config
./bin/operator --config /path/to/config.yaml

# With help
./bin/operator --help
```

### Starting the Aggregator

```bash
# With default config
./bin/aggregator

# With custom config
./bin/aggregator --config /path/to/config.yaml
```

### Monitoring

The operator exposes several monitoring endpoints:

- **Metrics**: `http://localhost:9090/metrics` (Prometheus format)
- **Health Check**: `http://localhost:9091/health`
- **Node API**: `http://localhost:9091/api/v1/`

### Key Features

#### State Aggregation
- Collects pool state from multiple chains
- Validates data consistency across operators
- Calculates global metrics and imbalances

#### Predictive Analytics
- Price prediction based on historical trends
- Liquidity forecasting
- Rebalancing need prediction

#### Cross-Chain Rebalancing
- Automated liquidity movement via Across Protocol
- Cost optimization and route selection
- Transaction monitoring and status tracking

#### Monitoring & Alerts
- Real-time performance metrics
- Health checks and uptime monitoring
- Alert system for critical issues

## Development

### Adding New Chains

1. Add chain configuration to `config/operator.yaml`
2. Implement chain-specific logic in `pkg/blockchain/`
3. Update state aggregation logic
4. Test with mock data

### Adding New Features

1. Create new package in `pkg/`
2. Implement interface contracts
3. Add configuration options
4. Update main operator logic
5. Add tests and documentation

### Testing

```bash
# Run unit tests
go test ./...

# Run integration tests
go test -tags=integration ./...

# Run with coverage
go test -cover ./...
```

## Troubleshooting

### Common Issues

1. **Key Loading Errors**: Ensure keys are in correct format and path
2. **Connection Issues**: Check RPC URLs and network connectivity
3. **Consensus Failures**: Verify operator registration and stake
4. **Rebalancing Failures**: Check Across Protocol integration

### Logs

Operator logs are structured JSON format:
```json
{
  "level": "info",
  "timestamp": "2024-01-01T00:00:00Z",
  "message": "State updated",
  "poolID": "0x...",
  "chainID": 1,
  "liquidity": "1000000000000000000000"
}
```

### Metrics

Key metrics to monitor:
- `synchook_operator_uptime_seconds`
- `synchook_pool_states_total`
- `synchook_rebalancing_requests_total`
- `synchook_state_update_latency_seconds`

## Security

- **Key Management**: Store keys securely, use hardware wallets for production
- **Network Security**: Use TLS for all communications
- **Access Control**: Implement proper authentication and authorization
- **Monitoring**: Monitor for suspicious activity and anomalies

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Submit a pull request

## License

MIT License - see LICENSE file for details
