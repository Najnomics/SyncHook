# SyncHook Operator

The SyncHook Operator is a Go-based service that monitors and coordinates cross-chain liquidity synchronization across multiple blockchains using EigenLayer AVS and Across Protocol integration.

## Features

- **Multi-chain Monitoring**: Monitors pool states across multiple blockchains
- **EigenLayer Integration**: Submits state updates to EigenLayer AVS
- **Automatic Rebalancing**: Automatically rebalances liquidity when price deviations are detected
- **Across Protocol Integration**: Uses Across Protocol for cross-chain transfers
- **High Availability**: Designed for production deployment with health checks and graceful shutdown
- **Configurable**: Highly configurable via YAML configuration files

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Ethereum      │    │    Arbitrum     │    │   Optimism      │
│   (Chain 1)     │    │   (Chain 42161) │    │   (Chain 10)    │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────┴─────────────┐
                    │     SyncHook Operator     │
                    │  ┌─────────────────────┐  │
                    │  │      Monitor        │  │
                    │  └─────────────────────┘  │
                    │  ┌─────────────────────┐  │
                    │  │    Rebalancer       │  │
                    │  └─────────────────────┘  │
                    │  ┌─────────────────────┐  │
                    │  │   EigenLayer AVS    │  │
                    │  └─────────────────────┘  │
                    └─────────────┬─────────────┘
                                  │
                    ┌─────────────┴─────────────┐
                    │     Across Protocol       │
                    │   (Cross-chain Bridge)    │
                    └───────────────────────────┘
```

## Quick Start

### Prerequisites

- Go 1.21 or later
- Docker and Docker Compose
- PostgreSQL (for production)
- Private keys for each chain you want to monitor

### Installation

1. Clone the repository:
```bash
git clone https://github.com/synchook/synchook-operator.git
cd synchook-operator
```

2. Install dependencies:
```bash
make deps
```

3. Configure the operator:
```bash
cp config.yaml.example config.yaml
# Edit config.yaml with your settings
```

4. Build and run:
```bash
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