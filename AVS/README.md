# SyncHook AVS (Actively Validated Service)

The SyncHook AVS is a comprehensive Go-based service that provides cross-chain liquidity synchronization across multiple blockchains using EigenLayer's Actively Validated Service infrastructure and Across Protocol integration. This service acts as the backend operator for the SyncHook ecosystem, monitoring Uniswap V4 pools and coordinating liquidity rebalancing across chains.

## Features

- **Uniswap V4 Integration**: Monitors and responds to Uniswap V4 hook events across multiple chains
- **EigenLayer AVS**: Leverages EigenLayer's decentralized validation network for secure cross-chain state synchronization
- **Multi-chain Monitoring**: Real-time monitoring of pool states across Ethereum, Arbitrum, Polygon, Base, and Optimism
- **Intelligent Rebalancing**: AI-powered liquidity rebalancing using predictive analytics and state aggregation
- **Across Protocol Integration**: Seamless cross-chain transfers using Across Protocol's bridge infrastructure
- **High Availability**: Production-ready with health checks, graceful shutdown, and comprehensive monitoring
- **Configurable**: Highly configurable via YAML configuration files with environment variable support

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Ethereum      │    │    Arbitrum     │    │   Polygon       │    │     Base        │
│   (Chain 1)     │    │   (Chain 42161) │    │   (Chain 137)   │    │   (Chain 8453)  │
│                 │    │                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Uniswap V4  │ │    │ │ Uniswap V4  │ │    │ │ Uniswap V4  │ │    │ │ Uniswap V4  │ │
│ │ SyncHook    │ │    │ │ SyncHook    │ │    │ │ SyncHook    │ │    │ │ SyncHook    │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │                      │
          └──────────────────────┼──────────────────────┼──────────────────────┘
                                 │                      │
                    ┌─────────────┴─────────────┐      │
                    │     SyncHook AVS          │      │
                    │  ┌─────────────────────┐  │      │
                    │  │   State Monitor     │  │      │
                    │  └─────────────────────┘  │      │
                    │  ┌─────────────────────┐  │      │
                    │  │ Predictive Analytics│  │      │
                    │  └─────────────────────┘  │      │
                    │  ┌─────────────────────┐  │      │
                    │  │ State Aggregator    │  │      │
                    │  └─────────────────────┘  │      │
                    │  ┌─────────────────────┐  │      │
                    │  │ EigenLayer AVS      │  │      │
                    │  └─────────────────────┘  │      │
                    └─────────────┬─────────────┘      │
                                  │                    │
                    ┌─────────────┴─────────────┐      │
                    │     Across Protocol       │      │
                    │   (Cross-chain Bridge)    │      │
                    └───────────────────────────┘      │
                                                       │
                    ┌─────────────────────────────────┴─────────────┐
                    │              Optimism                         │
                    │              (Chain 10)                       │
                    │                                               │
                    │ ┌─────────────────────────────────────────┐ │
                    │ │            Uniswap V4                   │ │
                    │ │            SyncHook                     │ │
                    │ └─────────────────────────────────────────┘ │
                    └─────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Go 1.21 or later
- Docker and Docker Compose
- PostgreSQL (for production)
- EigenLayer operator registration
- Private keys for each chain you want to monitor
- Access to Uniswap V4 testnet/mainnet

### Installation

1. Clone the SyncHook repository:
```bash
git clone https://github.com/synchook/synchook.git
cd synchook/AVS
```

2. Install dependencies:
```bash
make deps
```

3. Configure the AVS:
```bash
cp config.yaml.example config.yaml
# Edit config.yaml with your settings
```

4. Build and run:
```bash
make build
make run
```

### Docker Deployment

1. Build the Docker image:
```bash
make docker-build
```

2. Start all services:
```bash
make docker-run
```

3. View logs:
```bash
make docker-logs
```

## Configuration

The operator is configured via a YAML file. See `config.yaml` for a complete example.

### Key Configuration Sections

- **Chains**: Configure blockchain connections (RPC URLs, private keys, contract addresses)
- **EigenLayer**: Configure EigenLayer AVS connection
- **Across**: Configure Across Protocol integration
- **Database**: Configure PostgreSQL connection
- **Operator**: Configure operator behavior (intervals, thresholds, etc.)

### Environment Variables

- `DATABASE_PASSWORD`: Database password
- `ETHEREUM_PRIVATE_KEY`: Ethereum private key
- `ARBITRUM_PRIVATE_KEY`: Arbitrum private key
- `OPTIMISM_PRIVATE_KEY`: Optimism private key

## API Endpoints

The operator exposes a REST API for monitoring and control:

- `GET /health` - Health check endpoint
- `GET /status` - Operator status
- `GET /chains` - Chain status
- `GET /pools` - Pool states
- `POST /rebalance` - Trigger manual rebalancing

## Monitoring

The operator includes comprehensive logging and monitoring:

- Structured JSON logging
- Health check endpoints
- Prometheus metrics (planned)
- Grafana dashboards (planned)

## Development

### Running Tests

```bash
make test
```

### Running Tests with Coverage

```bash
make test-coverage
```

### Code Formatting

```bash
make fmt
```

### Linting

```bash
make lint
```

## Production Deployment

### Security Considerations

- Store private keys securely (use environment variables or secret management)
- Use TLS for all external connections
- Implement proper access controls
- Regular security audits

### Scaling

- Run multiple operator instances for high availability
- Use load balancers for API endpoints
- Consider database clustering for high throughput

### Monitoring

- Set up alerting for critical errors
- Monitor gas prices and transaction costs
- Track rebalancing performance and profitability

## Troubleshooting

### Common Issues

1. **Database Connection Failed**
   - Check database credentials and connectivity
   - Ensure PostgreSQL is running and accessible

2. **Chain Connection Failed**
   - Verify RPC URLs are correct and accessible
   - Check private key format and permissions

3. **EigenLayer Integration Issues**
   - Verify contract addresses are correct
   - Check operator registration status

### Logs

View detailed logs:
```bash
make docker-logs
```

Or for local development:
```bash
./synchook-operator start --config config.yaml
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue on GitHub
- Join our Discord community
- Check the documentation

## Roadmap

- [ ] Prometheus metrics integration
- [ ] Grafana dashboards
- [ ] Advanced rebalancing strategies
- [ ] Multi-signature support
- [ ] MEV protection
- [ ] Cross-chain state validation