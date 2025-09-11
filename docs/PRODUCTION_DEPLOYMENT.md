# SyncHook Production Deployment Guide

## 🚀 **Quick Start**

### **Prerequisites**
- Docker and Docker Compose
- 8GB+ RAM, 4+ CPU cores
- 100GB+ disk space
- Ubuntu 20.04+ or similar Linux distribution

### **1. Clone and Setup**
```bash
git clone https://github.com/synchook/synchook.git
cd synchook
```

### **2. Configure Environment**
```bash
cd deploy/production
cp env.example .env
# Edit .env with your configuration
nano .env
```

### **3. Deploy**
```bash
docker-compose -f docker-compose.prod.yml up -d
```

### **4. Verify Deployment**
```bash
# Check all services
docker-compose -f docker-compose.prod.yml ps

# Check logs
docker-compose -f docker-compose.prod.yml logs -f synchook-avs

# Check health
curl http://localhost:8080/health
```

## 🔧 **Detailed Configuration**

### **Environment Variables**

#### **Required Variables**
```bash
# Database
DATABASE_PASSWORD=your_secure_password

# Private Keys (KEEP SECURE!)
ETHEREUM_PRIVATE_KEY=0x...
ARBITRUM_PRIVATE_KEY=0x...
OPTIMISM_PRIVATE_KEY=0x...

# Monitoring
GRAFANA_PASSWORD=your_grafana_password
```

#### **Optional Variables**
```bash
# Logging
LOG_LEVEL=info

# Security
JWT_SECRET=your_jwt_secret
ENCRYPTION_KEY=your_encryption_key

# External APIs
INFURA_API_KEY=your_infura_key
ALCHEMY_API_KEY=your_alchemy_key
```

### **Network Configuration**

#### **Ports**
- **80/443**: Nginx (HTTP/HTTPS)
- **8080**: SyncHook AVS API
- **3000**: Grafana Dashboard
- **9090**: Prometheus
- **5432**: PostgreSQL
- **6379**: Redis

#### **Firewall Rules**
```bash
# Allow HTTP/HTTPS
ufw allow 80
ufw allow 443

# Allow SSH (if needed)
ufw allow 22

# Block other ports
ufw default deny incoming
ufw default allow outgoing
```

## 📊 **Monitoring Setup**

### **Grafana Dashboard**
1. Access: `http://your-server:3000`
2. Login: `admin` / `your_grafana_password`
3. Import dashboards from `monitoring/grafana/dashboards/`

### **Prometheus Metrics**
1. Access: `http://your-server:9090`
2. Check targets: Status → Targets
3. View metrics: Graph → Query

### **Key Metrics to Monitor**
- **Service Health**: `up{job="synchook-avs"}`
- **Request Rate**: `rate(http_requests_total[5m])`
- **Error Rate**: `rate(http_requests_total{status=~"5.."}[5m])`
- **Response Time**: `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))`

## 🔒 **Security Configuration**

### **SSL/TLS Setup**
```bash
# Generate SSL certificates
mkdir -p nginx/ssl
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/ssl/key.pem \
  -out nginx/ssl/cert.pem
```

### **Security Headers**
Nginx configuration includes:
- HSTS headers
- X-Frame-Options
- X-Content-Type-Options
- Content Security Policy

### **Access Control**
- Database: Password protected
- Redis: Password protected
- Grafana: Admin password required
- API: Rate limited and authenticated

## 🗄️ **Database Setup**

### **PostgreSQL Configuration**
```sql
-- Create database
CREATE DATABASE synchook;

-- Create user
CREATE USER synchook WITH PASSWORD 'your_password';

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE synchook TO synchook;
```

### **Database Migrations**
```bash
# Run migrations
docker-compose -f docker-compose.prod.yml exec synchook-avs \
  ./synchook-avs migrate up
```

## 🔄 **Backup Strategy**

### **Database Backup**
```bash
# Daily backup script
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
docker-compose -f docker-compose.prod.yml exec postgres \
  pg_dump -U synchook synchook > backup_$DATE.sql
```

### **Configuration Backup**
```bash
# Backup configuration
tar -czf config_backup_$(date +%Y%m%d).tar.gz \
  deploy/production/.env \
  deploy/production/monitoring/ \
  deploy/production/nginx/
```

## 📈 **Scaling**

### **Horizontal Scaling**
```yaml
# Scale AVS service
docker-compose -f docker-compose.prod.yml up -d --scale synchook-avs=3
```

### **Load Balancing**
Nginx automatically load balances between multiple AVS instances.

### **Database Scaling**
- Read replicas for read-heavy workloads
- Connection pooling for high concurrency
- Partitioning for large datasets

## 🚨 **Emergency Procedures**

### **Emergency Stop**
```bash
# Stop all services
docker-compose -f docker-compose.prod.yml down

# Stop specific service
docker-compose -f docker-compose.prod.yml stop synchook-avs
```

### **Emergency Mode**
```bash
# Activate emergency mode
curl -X POST http://localhost:8080/emergency/activate

# Deactivate emergency mode
curl -X POST http://localhost:8080/emergency/deactivate
```

### **Data Recovery**
```bash
# Restore database
docker-compose -f docker-compose.prod.yml exec postgres \
  psql -U synchook synchook < backup_20240101_120000.sql
```

## 🔍 **Troubleshooting**

### **Common Issues**

#### **Service Won't Start**
```bash
# Check logs
docker-compose -f docker-compose.prod.yml logs synchook-avs

# Check configuration
docker-compose -f docker-compose.prod.yml config
```

#### **Database Connection Issues**
```bash
# Test database connection
docker-compose -f docker-compose.prod.yml exec postgres \
  psql -U synchook -d synchook -c "SELECT 1;"
```

#### **High Memory Usage**
```bash
# Check memory usage
docker stats

# Restart service
docker-compose -f docker-compose.prod.yml restart synchook-avs
```

### **Log Analysis**
```bash
# View all logs
docker-compose -f docker-compose.prod.yml logs

# Follow specific service logs
docker-compose -f docker-compose.prod.yml logs -f synchook-avs

# Search logs
docker-compose -f docker-compose.prod.yml logs synchook-avs | grep ERROR
```

## 📋 **Maintenance**

### **Regular Tasks**
- **Daily**: Check service health and logs
- **Weekly**: Review metrics and alerts
- **Monthly**: Update dependencies and security patches
- **Quarterly**: Review and update configuration

### **Updates**
```bash
# Pull latest changes
git pull origin main

# Rebuild and restart
docker-compose -f docker-compose.prod.yml build
docker-compose -f docker-compose.prod.yml up -d
```

### **Health Checks**
```bash
# Service health
curl http://localhost:8080/health

# Database health
curl http://localhost:8080/health/database

# Redis health
curl http://localhost:8080/health/redis
```

## 📞 **Support**

### **Monitoring Dashboards**
- **Grafana**: `http://your-server:3000`
- **Prometheus**: `http://your-server:9090`

### **Log Aggregation**
- **Loki**: `http://your-server:3100`
- **Logs**: `./logs/` directory

### **Emergency Contacts**
- **On-call**: +1-XXX-XXX-XXXX
- **Email**: support@synchook.io
- **Discord**: https://discord.gg/synchook

## ✅ **Deployment Checklist**

### **Pre-Deployment**
- [ ] Environment variables configured
- [ ] SSL certificates generated
- [ ] Database credentials set
- [ ] Private keys secured
- [ ] Monitoring configured

### **Deployment**
- [ ] All services started successfully
- [ ] Health checks passing
- [ ] Monitoring dashboards accessible
- [ ] Logs being collected
- [ ] Alerts configured

### **Post-Deployment**
- [ ] Load testing completed
- [ ] Security scan passed
- [ ] Backup strategy implemented
- [ ] Documentation updated
- [ ] Team trained on operations

## 🎯 **Success Metrics**

### **Performance Targets**
- **Uptime**: >99.9%
- **Response Time**: <1s (95th percentile)
- **Error Rate**: <0.1%
- **Throughput**: >1000 requests/second

### **Business Metrics**
- **Cross-chain transfers**: Tracked and monitored
- **Rebalancing operations**: Success rate >95%
- **State updates**: Real-time synchronization
- **User satisfaction**: >4.5/5 rating

**SyncHook is now production-ready and deployed!** 🚀
