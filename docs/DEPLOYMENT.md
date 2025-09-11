# SyncHook Deployment Guide

## Overview

This guide provides comprehensive instructions for deploying the SyncHook system across multiple environments. The deployment includes smart contracts, Go-based operator services, monitoring, and infrastructure components.

## Prerequisites

### System Requirements
- **Go**: Version 1.21.5 or later
- **Node.js**: Version 18 or later (for frontend)
- **Docker**: Version 20.10 or later
- **Docker Compose**: Version 2.0 or later
- **Foundry**: Latest version for smart contract deployment
- **Git**: For cloning repositories

### Network Access
- Access to Ethereum mainnet and testnets
- Access to Arbitrum and Polygon networks
- Access to Across Protocol
- Access to EigenLayer contracts

### Accounts and Keys
- Ethereum account with sufficient ETH for gas
- Private keys for contract deployment
- Operator keys for AVS registration
- Across Protocol configuration

## Environment Setup

### 1. Clone Repository
```bash
git clone https://github.com/your-org/synchook.git
cd synchook
```

### 2. Install Dependencies

#### Go Dependencies
```bash
cd operator
go mod tidy
```

#### Node.js Dependencies
```bash
cd frontend
npm install
```

#### Foundry Dependencies
```bash
forge install
```

### 3. Environment Configuration

#### Create Environment Files
```bash
# Copy example environment files
cp .env.example .env
cp operator/.env.example operator/.env
cp frontend/.env.example frontend/.env
```

#### Configure Environment Variables
```bash
# .env
ETH_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY
ARBITRUM_RPC_URL=https://arb-mainnet.g.alchemy.com/v2/YOUR_API_KEY
POLYGON_RPC_URL=https://polygon-mainnet.g.alchemy.com/v2/YOUR_API_KEY
PRIVATE_KEY=your_private_key_here
ACROSS_ADDRESS=0x1234567890123456789012345678901234567890
EIGENLAYER_REGISTRY_COORDINATOR=0x1234567890123456789012345678901234567890
```

## Smart Contract Deployment

### 1. Compile Contracts
```bash
forge build
```

### 2. Deploy Core Contracts

#### Deploy State Validation Middleware
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url $ETH_RPC_URL --broadcast --verify
```

#### Deploy SyncAVS
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url $ETH_RPC_URL --broadcast --verify
```

#### Deploy SyncTaskManager
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url $ETH_RPC_URL --broadcast --verify
```

#### Deploy AcrossIntegration
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url $ETH_RPC_URL --broadcast --verify
```

#### Deploy SyncHook
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url $ETH_RPC_URL --broadcast --verify
```

### 3. Configure Contracts

#### Setup AVS
```bash
forge script script/SetupAVS.s.sol:SetupAVSScript --rpc-url $ETH_RPC_URL --broadcast
```

#### Register Operator
```bash
forge script script/RegisterOperator.s.sol:RegisterOperatorScript --rpc-url $ETH_RPC_URL --broadcast
```

#### Configure Chains
```bash
forge script script/ConfigureChains.s.sol:ConfigureChainsScript --rpc-url $ETH_RPC_URL --broadcast
```

### 4. Deploy to Additional Chains

#### Arbitrum Deployment
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url $ARBITRUM_RPC_URL --broadcast --verify
```

#### Polygon Deployment
```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url $POLYGON_RPC_URL --broadcast --verify
```

## Go Operator Deployment

### 1. Build Operator
```bash
cd operator
go build -o bin/operator cmd/operator/main.go
go build -o bin/aggregator cmd/aggregator/main.go
```

### 2. Configure Operator

#### Create Configuration Files
```bash
# operator/config/operator.yaml
ethRpcUrl: "https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
arbitrumRpcUrl: "https://arb-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
polygonRpcUrl: "https://polygon-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
registryCoordinatorAddress: "0x1234567890123456789012345678901234567890"
syncAVSAddress: "0x1234567890123456789012345678901234567890"
acrossAddress: "0x1234567890123456789012345678901234567890"
ecdsaPrivateKeyStorePath: "keys/operator.ecdsa.key.json"
blsPrivateKeyStorePath: "keys/operator.bls.key.json"
enableMetrics: true
enableNodeApi: true
eigenMetricsIpPortAddress: "0.0.0.0:9090"
nodeApiIpPortAddress: "0.0.0.0:8080"
registerOperatorOnStartup: true
```

### 3. Generate Operator Keys

#### Generate ECDSA Key
```bash
# Use existing key or generate new one
# Place in keys/operator.ecdsa.key.json
```

#### Generate BLS Key
```bash
# Use existing key or generate new one
# Place in keys/operator.bls.key.json
```

### 4. Run Operator

#### Local Development
```bash
./bin/operator --config config/operator.yaml
```

#### Production with Docker
```bash
docker build -t synchook-operator .
docker run -d --name synchook-operator \
  -v $(pwd)/config:/app/config \
  -v $(pwd)/keys:/app/keys \
  synchook-operator
```

## Frontend Deployment

### 1. Build Frontend
```bash
cd frontend
npm run build
```

### 2. Deploy Frontend

#### Local Development
```bash
npm run dev
```

#### Production with Docker
```bash
docker build -t synchook-frontend .
docker run -d --name synchook-frontend -p 3000:3000 synchook-frontend
```

#### Static Hosting (Vercel/Netlify)
```bash
# Deploy to Vercel
vercel --prod

# Deploy to Netlify
netlify deploy --prod --dir=dist
```

## Infrastructure Deployment

### 1. Docker Compose

#### Create docker-compose.yml
```yaml
version: '3.8'
services:
  operator:
    build: ./operator
    ports:
      - "8080:8080"
      - "9090:9090"
    volumes:
      - ./operator/config:/app/config
      - ./operator/keys:/app/keys
    environment:
      - CONFIG_PATH=/app/config/operator.yaml
    restart: unless-stopped

  aggregator:
    build: ./operator
    command: ./bin/aggregator
    ports:
      - "8081:8080"
    volumes:
      - ./operator/config:/app/config
    environment:
      - CONFIG_PATH=/app/config/aggregator.yaml
    restart: unless-stopped

  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    environment:
      - REACT_APP_API_URL=http://localhost:8080
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9091:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3001:3000"
    volumes:
      - ./monitoring/grafana:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    restart: unless-stopped
```

#### Deploy with Docker Compose
```bash
docker-compose up -d
```

### 2. Kubernetes Deployment

#### Create Namespace
```bash
kubectl create namespace synchook
```

#### Deploy Operator
```bash
kubectl apply -f k8s/operator-deployment.yaml
kubectl apply -f k8s/operator-service.yaml
```

#### Deploy Aggregator
```bash
kubectl apply -f k8s/aggregator-deployment.yaml
kubectl apply -f k8s/aggregator-service.yaml
```

#### Deploy Frontend
```bash
kubectl apply -f k8s/frontend-deployment.yaml
kubectl apply -f k8s/frontend-service.yaml
```

#### Deploy Monitoring
```bash
kubectl apply -f k8s/monitoring/
```

### 3. Terraform Deployment

#### Initialize Terraform
```bash
cd terraform
terraform init
```

#### Plan Deployment
```bash
terraform plan
```

#### Apply Configuration
```bash
terraform apply
```

## Monitoring Setup

### 1. Prometheus Configuration

#### Create prometheus.yml
```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'synchook-operator'
    static_configs:
      - targets: ['operator:9090']
  
  - job_name: 'synchook-aggregator'
    static_configs:
      - targets: ['aggregator:9090']
```

### 2. Grafana Dashboards

#### Import Dashboards
```bash
# Import operator dashboard
curl -X POST http://admin:admin@localhost:3001/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @monitoring/grafana/operator-dashboard.json

# Import aggregator dashboard
curl -X POST http://admin:admin@localhost:3001/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @monitoring/grafana/aggregator-dashboard.json
```

### 3. Alerting Rules

#### Create Alert Rules
```yaml
groups:
  - name: synchook
    rules:
      - alert: OperatorDown
        expr: up{job="synchook-operator"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "SyncHook operator is down"
      
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High error rate detected"
```

## Security Configuration

### 1. Network Security

#### Firewall Rules
```bash
# Allow only necessary ports
ufw allow 22    # SSH
ufw allow 80    # HTTP
ufw allow 443   # HTTPS
ufw allow 8080  # Operator API
ufw allow 9090  # Metrics
ufw enable
```

#### SSL/TLS Configuration
```bash
# Generate SSL certificates
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
```

### 2. Access Control

#### API Authentication
```bash
# Generate API keys
openssl rand -hex 32
```

#### Database Security
```bash
# Secure database access
# Use strong passwords
# Enable encryption at rest
# Configure access controls
```

### 3. Key Management

#### Secure Key Storage
```bash
# Use hardware security modules (HSM) for production
# Encrypt keys at rest
# Implement key rotation policies
# Use secure key distribution mechanisms
```

## Testing Deployment

### 1. Health Checks

#### Check Operator Health
```bash
curl http://localhost:8080/health
```

#### Check Aggregator Health
```bash
curl http://localhost:8081/health
```

#### Check Frontend
```bash
curl http://localhost:3000
```

### 2. Integration Tests

#### Run Test Suite
```bash
# Run smart contract tests
forge test

# Run operator tests
cd operator
go test ./...

# Run frontend tests
cd frontend
npm test
```

### 3. Load Testing

#### Test Operator Performance
```bash
# Use tools like Apache Bench or wrk
ab -n 1000 -c 10 http://localhost:8080/api/v1/status
```

## Troubleshooting

### 1. Common Issues

#### Contract Deployment Failures
- Check gas limits
- Verify RPC URLs
- Ensure sufficient ETH balance
- Check contract bytecode

#### Operator Connection Issues
- Verify RPC connectivity
- Check configuration files
- Ensure proper key files
- Check network connectivity

#### Frontend Build Issues
- Check Node.js version
- Clear npm cache
- Verify environment variables
- Check build logs

### 2. Log Analysis

#### View Operator Logs
```bash
docker logs synchook-operator
```

#### View Aggregator Logs
```bash
docker logs synchook-aggregator
```

#### View Frontend Logs
```bash
docker logs synchook-frontend
```

### 3. Performance Monitoring

#### Monitor Resource Usage
```bash
docker stats
```

#### Check Metrics
```bash
curl http://localhost:9090/metrics
```

## Maintenance

### 1. Regular Updates

#### Update Dependencies
```bash
# Update Go dependencies
cd operator
go get -u ./...

# Update Node.js dependencies
cd frontend
npm update

# Update Foundry dependencies
forge update
```

#### Update Contracts
```bash
# Deploy updated contracts
forge script script/Deploy.s.sol:DeployScript --rpc-url $ETH_RPC_URL --broadcast --verify
```

### 2. Backup Procedures

#### Backup Configuration
```bash
# Backup configuration files
tar -czf config-backup-$(date +%Y%m%d).tar.gz config/
```

#### Backup Keys
```bash
# Backup operator keys (encrypt first)
gpg -c keys/operator.ecdsa.key.json
gpg -c keys/operator.bls.key.json
```

### 3. Disaster Recovery

#### Recovery Procedures
1. Restore configuration files
2. Restore operator keys
3. Redeploy contracts if necessary
4. Restart services
5. Verify functionality

## Production Considerations

### 1. High Availability

#### Multiple Operators
- Deploy multiple operator instances
- Use load balancers
- Implement failover mechanisms

#### Database Clustering
- Use database clusters
- Implement replication
- Configure automatic failover

### 2. Scalability

#### Horizontal Scaling
- Add more operator instances
- Scale aggregator services
- Use container orchestration

#### Performance Optimization
- Optimize database queries
- Implement caching
- Use CDN for frontend

### 3. Security

#### Regular Audits
- Conduct security audits
- Perform penetration testing
- Review access controls

#### Monitoring
- Implement comprehensive monitoring
- Set up alerting
- Regular security reviews
