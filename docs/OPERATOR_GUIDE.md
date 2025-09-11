# SyncHook Operator Guide

## Overview

This guide provides comprehensive instructions for running and managing SyncHook operators. Operators are responsible for maintaining the AVS (Actively Validated Service) by processing tasks, validating state updates, and participating in consensus mechanisms.

## Operator Responsibilities

### Core Functions
1. **State Aggregation**: Collect and aggregate pool state data from multiple chains
2. **Task Processing**: Process assigned tasks from the AVS service manager
3. **Consensus Participation**: Participate in consensus mechanisms for state validation
4. **Cross-Chain Monitoring**: Monitor cross-chain operations and liquidity movements
5. **Rebalancing Execution**: Execute rebalancing operations when needed

### Economic Responsibilities
1. **Staking**: Maintain required stake in the AVS
2. **Performance**: Maintain high performance to avoid slashing
3. **Uptime**: Ensure high uptime for reliable service
4. **Security**: Maintain secure operations to protect the network

## Prerequisites

### System Requirements
- **Operating System**: Linux (Ubuntu 20.04+ recommended)
- **CPU**: 4+ cores
- **RAM**: 8GB+ (16GB recommended)
- **Storage**: 100GB+ SSD
- **Network**: Stable internet connection with low latency

### Software Requirements
- **Go**: Version 1.21.5 or later
- **Docker**: Version 20.10 or later (optional)
- **Git**: For code management
- **Node.js**: Version 18+ (for monitoring tools)

### Network Access
- Access to Ethereum mainnet
- Access to Arbitrum and Polygon networks
- Access to Across Protocol
- Access to EigenLayer contracts

## Installation

### 1. Clone Repository
```bash
git clone https://github.com/your-org/synchook.git
cd synchook/operator
```

### 2. Install Dependencies
```bash
go mod tidy
```

### 3. Build Operator
```bash
go build -o bin/operator cmd/operator/main.go
go build -o bin/aggregator cmd/aggregator/main.go
```

### 4. Create Configuration
```bash
cp config/operator.yaml.example config/operator.yaml
# Edit configuration file with your settings
```

## Configuration

### Operator Configuration (`config/operator.yaml`)

```yaml
# Network Configuration
ethRpcUrl: "https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
arbitrumRpcUrl: "https://arb-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
polygonRpcUrl: "https://polygon-mainnet.g.alchemy.com/v2/YOUR_API_KEY"

# Contract Addresses
registryCoordinatorAddress: "0x1234567890123456789012345678901234567890"
syncAVSAddress: "0x1234567890123456789012345678901234567890"
acrossAddress: "0x1234567890123456789012345678901234567890"

# Operator Keys
ecdsaPrivateKeyStorePath: "keys/operator.ecdsa.key.json"
blsPrivateKeyStorePath: "keys/operator.bls.key.json"

# Service Configuration
enableMetrics: true
enableNodeApi: true
eigenMetricsIpPortAddress: "0.0.0.0:9090"
nodeApiIpPortAddress: "0.0.0.0:8080"

# Registration
registerOperatorOnStartup: true

# Supported Chains
supportedChains:
  - chainID: 1
    name: "Ethereum"
    rpcUrl: "https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
  - chainID: 42161
    name: "Arbitrum"
    rpcUrl: "https://arb-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
  - chainID: 137
    name: "Polygon"
    rpcUrl: "https://polygon-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
```

### Aggregator Configuration (`config/aggregator.yaml`)

```yaml
# Network Configuration
ethRpcUrl: "https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
arbitrumRpcUrl: "https://arb-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
polygonRpcUrl: "https://polygon-mainnet.g.alchemy.com/v2/YOUR_API_KEY"

# Contract Addresses
syncAVSAddress: "0x1234567890123456789012345678901234567890"
acrossAddress: "0x1234567890123456789012345678901234567890"

# Service Configuration
enableMetrics: true
eigenMetricsIpPortAddress: "0.0.0.0:9090"

# Aggregation Settings
aggregationInterval: "30s"
maxRetries: 3
timeout: "10s"
```

## Key Management

### 1. Generate ECDSA Key

#### Using Existing Key
```bash
# If you have an existing private key, create the keystore file
# Format: {"address":"0x...","crypto":{...},"id":"...","version":3}
```

#### Generate New Key
```bash
# Use tools like geth or web3 to generate new key
# geth account new --keystore keys/
```

### 2. Generate BLS Key

#### Using Existing Key
```bash
# If you have an existing BLS key, create the keystore file
# Format: {"privateKey":"...","publicKey":"...","id":"...","version":1}
```

#### Generate New Key
```bash
# Use the operator to generate new BLS key
./bin/operator --generate-bls-key --output keys/operator.bls.key.json
```

### 3. Secure Key Storage

#### File Permissions
```bash
chmod 600 keys/operator.ecdsa.key.json
chmod 600 keys/operator.bls.key.json
```

#### Encryption
```bash
# Encrypt keys for additional security
gpg -c keys/operator.ecdsa.key.json
gpg -c keys/operator.bls.key.json
```

## Running the Operator

### 1. Local Development

#### Start Operator
```bash
./bin/operator --config config/operator.yaml
```

#### Start Aggregator
```bash
./bin/aggregator --config config/aggregator.yaml
```

### 2. Production Deployment

#### Using Docker
```bash
# Build image
docker build -t synchook-operator .

# Run operator
docker run -d --name synchook-operator \
  -v $(pwd)/config:/app/config \
  -v $(pwd)/keys:/app/keys \
  synchook-operator
```

#### Using Systemd
```bash
# Create systemd service file
sudo tee /etc/systemd/system/synchook-operator.service > /dev/null <<EOF
[Unit]
Description=SyncHook Operator
After=network.target

[Service]
Type=simple
User=synchook
WorkingDirectory=/opt/synchook/operator
ExecStart=/opt/synchook/operator/bin/operator --config config/operator.yaml
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
sudo systemctl enable synchook-operator
sudo systemctl start synchook-operator
```

### 3. Docker Compose

#### Create docker-compose.yml
```yaml
version: '3.8'
services:
  operator:
    build: .
    ports:
      - "8080:8080"
      - "9090:9090"
    volumes:
      - ./config:/app/config
      - ./keys:/app/keys
    environment:
      - CONFIG_PATH=/app/config/operator.yaml
    restart: unless-stopped

  aggregator:
    build: .
    command: ./bin/aggregator
    ports:
      - "8081:8080"
    volumes:
      - ./config:/app/config
    environment:
      - CONFIG_PATH=/app/config/aggregator.yaml
    restart: unless-stopped
```

#### Deploy
```bash
docker-compose up -d
```

## Monitoring and Maintenance

### 1. Health Checks

#### Check Operator Status
```bash
curl http://localhost:8080/health
```

#### Check Metrics
```bash
curl http://localhost:9090/metrics
```

#### Check Logs
```bash
# Docker
docker logs synchook-operator

# Systemd
sudo journalctl -u synchook-operator -f
```

### 2. Performance Monitoring

#### Key Metrics
- **Uptime**: Operator availability
- **Task Processing Rate**: Tasks processed per second
- **State Update Latency**: Time to process state updates
- **Cross-Chain Operations**: Success rate of cross-chain operations
- **Stake Status**: Current stake and slashing risk

#### Monitoring Tools
```bash
# Install monitoring tools
go install github.com/prometheus/prometheus/cmd/prometheus@latest
go install github.com/grafana/grafana@latest

# Start Prometheus
prometheus --config.file=monitoring/prometheus.yml

# Start Grafana
grafana-server --config=monitoring/grafana.ini
```

### 3. Log Management

#### Log Levels
- **DEBUG**: Detailed debugging information
- **INFO**: General information
- **WARN**: Warning messages
- **ERROR**: Error messages
- **FATAL**: Fatal errors

#### Log Rotation
```bash
# Configure logrotate
sudo tee /etc/logrotate.d/synchook-operator > /dev/null <<EOF
/var/log/synchook-operator/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 synchook synchook
}
EOF
```

## Troubleshooting

### 1. Common Issues

#### Connection Issues
```bash
# Check RPC connectivity
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  $ETH_RPC_URL

# Check network latency
ping -c 4 eth-mainnet.g.alchemy.com
```

#### Key Issues
```bash
# Verify key files exist and are readable
ls -la keys/
cat keys/operator.ecdsa.key.json | jq .
cat keys/operator.bls.key.json | jq .
```

#### Configuration Issues
```bash
# Validate configuration
./bin/operator --config config/operator.yaml --validate-config
```

### 2. Performance Issues

#### High CPU Usage
```bash
# Check CPU usage
top -p $(pgrep operator)

# Profile CPU usage
go tool pprof http://localhost:8080/debug/pprof/profile
```

#### High Memory Usage
```bash
# Check memory usage
ps aux | grep operator

# Profile memory usage
go tool pprof http://localhost:8080/debug/pprof/heap
```

#### Network Issues
```bash
# Check network connections
netstat -tulpn | grep operator

# Check network latency
ping -c 10 eth-mainnet.g.alchemy.com
```

### 3. Error Handling

#### Common Errors
1. **"Failed to connect to RPC"**: Check RPC URL and network connectivity
2. **"Invalid key format"**: Verify key file format and permissions
3. **"Insufficient stake"**: Ensure sufficient stake is deposited
4. **"Task processing failed"**: Check logs for specific error details

#### Error Recovery
```bash
# Restart operator
sudo systemctl restart synchook-operator

# Check status
sudo systemctl status synchook-operator

# View logs
sudo journalctl -u synchook-operator --since "1 hour ago"
```

## Security Best Practices

### 1. Key Security

#### Key Storage
- Store keys in secure, encrypted storage
- Use hardware security modules (HSM) for production
- Implement key rotation policies
- Never share private keys

#### Access Control
- Limit access to key files
- Use strong file permissions
- Implement multi-factor authentication
- Regular security audits

### 2. Network Security

#### Firewall Configuration
```bash
# Allow only necessary ports
ufw allow 22    # SSH
ufw allow 8080  # Operator API
ufw allow 9090  # Metrics
ufw deny 3000   # Block unnecessary ports
ufw enable
```

#### SSL/TLS
```bash
# Generate SSL certificates
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

# Configure HTTPS
# Update configuration to use HTTPS
```

### 3. Operational Security

#### Regular Updates
```bash
# Update dependencies
go get -u ./...

# Update system packages
sudo apt update && sudo apt upgrade
```

#### Monitoring
- Monitor for suspicious activity
- Set up alerting for security events
- Regular security scans
- Incident response procedures

## Staking and Economics

### 1. Stake Management

#### Deposit Stake
```bash
# Deposit stake to EigenLayer
# Use EigenLayer interface or CLI tools
```

#### Monitor Stake
```bash
# Check stake status
curl http://localhost:8080/api/v1/stake/status
```

#### Withdraw Stake
```bash
# Withdraw stake (after unbonding period)
# Use EigenLayer interface or CLI tools
```

### 2. Rewards and Slashing

#### Monitor Rewards
```bash
# Check reward balance
curl http://localhost:8080/api/v1/rewards/balance
```

#### Monitor Slashing Risk
```bash
# Check slashing risk
curl http://localhost:8080/api/v1/slashing/risk
```

### 3. Economic Optimization

#### Performance Metrics
- Maintain high uptime (>99%)
- Process tasks quickly and accurately
- Minimize errors and slashing risk
- Optimize gas usage

#### Cost Management
- Monitor gas costs
- Optimize transaction batching
- Use efficient RPC providers
- Implement cost monitoring

## Advanced Configuration

### 1. Custom Chains

#### Add New Chain
```yaml
supportedChains:
  - chainID: 10
    name: "Optimism"
    rpcUrl: "https://opt-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
```

#### Configure Chain-Specific Settings
```yaml
chainConfigs:
  10:
    gasLimit: 2000000
    gasPrice: 1000000000
    timeout: "30s"
```

### 2. Custom Metrics

#### Add Custom Metrics
```go
// In operator code
customMetric := prometheus.NewCounterVec(
    prometheus.CounterOpts{
        Name: "custom_operations_total",
        Help: "Total number of custom operations",
    },
    []string{"operation_type"},
)
```

#### Configure Alerting
```yaml
# In monitoring configuration
alerts:
  - name: "HighCustomOperationRate"
    expr: "rate(custom_operations_total[5m]) > 10"
    for: "2m"
    labels:
      severity: "warning"
```

### 3. Integration with External Systems

#### Webhook Integration
```yaml
webhooks:
  - url: "https://your-webhook.com/events"
    events: ["task_completed", "error_occurred"]
    timeout: "5s"
    retries: 3
```

#### Database Integration
```yaml
database:
  type: "postgresql"
  host: "localhost"
  port: 5432
  name: "synchook"
  user: "operator"
  password: "secure_password"
```

## Support and Community

### 1. Getting Help

#### Documentation
- Read this guide thoroughly
- Check the main README.md
- Review API documentation
- Check troubleshooting section

#### Community Support
- Join Discord server
- Post on GitHub issues
- Check FAQ section
- Contact support team

### 2. Contributing

#### Bug Reports
- Use GitHub issues
- Provide detailed information
- Include logs and configuration
- Follow issue templates

#### Feature Requests
- Use GitHub discussions
- Describe use case
- Provide implementation ideas
- Get community feedback

#### Code Contributions
- Fork repository
- Create feature branch
- Submit pull request
- Follow coding standards

### 3. Updates and Maintenance

#### Regular Updates
- Check for updates weekly
- Test updates in staging
- Deploy updates carefully
- Monitor after deployment

#### Long-term Maintenance
- Plan for hardware upgrades
- Monitor performance trends
- Update security measures
- Plan for scaling needs
