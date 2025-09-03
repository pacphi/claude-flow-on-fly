# Advanced Features

## Database Integration

### PostgreSQL Integration

**Deploy PostgreSQL Database:**

```bash
# Create PostgreSQL cluster
flyctl postgres create --name my-postgres \
    --region iad \
    --vm-size shared-cpu-1x \
    --volume-size 10 \
    --initial-cluster-size 1

# Attach to development VM
flyctl postgres attach my-postgres -a my-claude-dev

# Connection will be available as DATABASE_URL environment variable
```

**Database Management:**

```bash
# Connect to database
flyctl postgres connect -a my-postgres

# Create development database
createdb -h my-postgres.internal development

# Run migrations in project
cd /workspace/projects/active/my-app
npm run migrate

# Backup database
pg_dump $DATABASE_URL > /workspace/backups/db-backup-$(date +%Y%m%d).sql
```

### Redis Integration

**Deploy Redis Cache:**

```bash
# Create Redis instance
flyctl redis create --name my-cache \
    --region iad \
    --plan shared-cpu-1x \
    --eviction allkeys-lru

# Attach to VM
flyctl redis attach my-cache -a my-claude-dev

# Redis URL available as REDIS_URL
```

**Redis Usage:**

```bash
# Connect to Redis
redis-cli -u $REDIS_URL

# Use in applications
cat > /workspace/projects/active/cache-example.js << 'EOF'
const redis = require('redis');
const client = redis.createClient({
    url: process.env.REDIS_URL
});

await client.connect();
await client.set('key', 'value');
const value = await client.get('key');
EOF
```

## Custom Domains and SSL

### Domain Configuration

**Add Custom Domain:**

```bash
# Add certificate for custom domain
flyctl certs create dev.company.com -a my-claude-dev

# Configure DNS (A record)
# dev.company.com -> [Fly.io IP address from above command]

# Verify certificate
flyctl certs show dev.company.com -a my-claude-dev
```

**Subdomain for Development:**

```bash
# Multiple subdomains
flyctl certs create api-dev.company.com -a my-claude-dev
flyctl certs create admin-dev.company.com -a my-claude-dev

# Wildcard certificate
flyctl certs create "*.dev.company.com" -a my-claude-dev
```

### HTTP Service Configuration

**Web Service Setup:**

```toml
# fly.toml
[[services]]
  protocol = "tcp"
  internal_port = 3000
  processes = ["web"]

  [[services.ports]]
    port = 80
    handlers = ["http"]
    force_https = true

  [[services.ports]]
    port = 443
    handlers = ["http", "tls"]

  [services.concurrency]
    type = "connections"
    hard_limit = 25
    soft_limit = 20

  [[services.tcp_checks]]
    interval = "15s"
    timeout = "2s"
    grace_period = "1s"
```

## Multi-Region Deployment

### Global Development Team

**Deploy in Multiple Regions:**

```bash
# Primary development (US East)
./scripts/vm-setup.sh --app-name dev-east --region iad

# European team (Europe)
./scripts/vm-setup.sh --app-name dev-europe --region lhr

# Asian team (Asia Pacific)
./scripts/vm-setup.sh --app-name dev-asia --region nrt
```

**Region-Specific Configuration:**

```bash
# Configure region-specific settings
cat > /workspace/scripts/region-config.sh << 'EOF'
#!/bin/bash
REGION=$(flyctl status --json | jq -r '.Region')

case $REGION in
    "iad"|"ord"|"lax")
        echo "US region configuration"
        export TZ="America/New_York"
        ;;
    "lhr"|"ams"|"cdg")
        echo "Europe region configuration"
        export TZ="Europe/London"
        ;;
    "nrt"|"hkg"|"sin")
        echo "Asia region configuration"
        export TZ="Asia/Tokyo"
        ;;
esac
EOF
```

### Data Replication

**Cross-Region Backup:**

```bash
# Replicate backups across regions
cat > /workspace/scripts/cross-region-backup.sh << 'EOF'
#!/bin/bash
PRIMARY_REGION="iad"
BACKUP_REGIONS=("lhr" "nrt")

# Create backup in primary region
./scripts/volume-backup.sh --region $PRIMARY_REGION

# Replicate to backup regions
for region in "${BACKUP_REGIONS[@]}"; do
    flyctl volumes create backup-$(date +%Y%m%d) \
        --region $region \
        --snapshot-id [snapshot-id] \
        -a dev-$region
done
EOF
```

## CI/CD Integration

### GitHub Actions Integration

**Automated Testing:**

```yaml
# .github/workflows/remote-dev-test.yml
name: Remote Development Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test-on-fly:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - name: Setup Fly CLI
        uses: superfly/flyctl-actions/setup-flyctl@master

      - name: Deploy test environment
        run: |
          flyctl deploy --remote-only \
            --build-arg ENVIRONMENT=test \
            -a test-claude-dev

      - name: Run tests
        run: |
          flyctl ssh console -a test-claude-dev \
            "cd /workspace/projects/active && npm test"

      - name: Cleanup
        if: always()
        run: |
          flyctl apps destroy test-claude-dev --yes
```

**Deployment Pipeline:**

```yaml
# .github/workflows/deploy.yml
name: Deploy to Development

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - name: Setup Fly CLI
        uses: superfly/flyctl-actions/setup-flyctl@master

      - name: Deploy to development
        run: |
          flyctl deploy --remote-only -a my-claude-dev
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

### Automated Environment Setup

## GPU and ML Workloads

### GPU-Enabled Development

**GPU Machine Configuration:**

```bash
# Deploy with GPU support (when available)
flyctl machine run \
    --app my-claude-dev \
    --region ord \
    --vm-size a100-40gb \
    --env GPU_ENABLED=true \
    my-claude-dev:gpu

# Install CUDA toolkit
cat > /workspace/scripts/extensions.d/15-cuda.sh << 'EOF'
#!/bin/bash
source /workspace/scripts/lib/common.sh

if nvidia-smi &> /dev/null; then
    print_status "Installing CUDA toolkit..."

    # Install CUDA
    wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.0-1_all.deb
    dpkg -i cuda-keyring_1.0-1_all.deb
    apt update
    apt install cuda-toolkit-12-0 -y

    # Install PyTorch with CUDA
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

    print_success "CUDA toolkit installed"
else
    print_warning "No GPU detected, skipping CUDA installation"
fi
EOF
```

### ML Development Environment

**Complete ML Stack:**

```bash
#!/bin/bash
# /workspace/scripts/extensions.d/20-ml-stack.sh
source /workspace/scripts/lib/common.sh

print_status "Setting up ML development environment..."

# Python ML packages
pip install \
    jupyter \
    pandas \
    numpy \
    matplotlib \
    seaborn \
    scikit-learn \
    tensorflow \
    torch \
    transformers \
    datasets \
    accelerate \
    wandb

# Jupyter Lab extensions
pip install jupyterlab-git jupyterlab-lsp
jupyter labextension install @jupyter-widgets/jupyterlab-manager

# R for statistics
apt install r-base r-base-dev -y
R -e "install.packages(c('tidyverse', 'caret', 'randomForest'), repos='http://cran.rstudio.com/')"

print_success "ML environment ready"
```

## Container and Orchestration

### Docker-in-Docker

**Docker Development:**

```bash
# Enable Docker in the development environment
cat > /workspace/scripts/extensions.d/30-docker-advanced.sh << 'EOF'
#!/bin/bash
source /workspace/scripts/lib/common.sh

print_status "Setting up Docker development..."

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker developer

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Configure Docker daemon
cat > /etc/docker/daemon.json << 'DOCKER_EOF'
{
    "data-root": "/workspace/docker",
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    }
}
DOCKER_EOF

systemctl restart docker

print_success "Docker environment ready"
EOF
```

### Kubernetes Development

**Local Kubernetes:**

```bash
# Install k3s lightweight Kubernetes
cat > /workspace/scripts/extensions.d/40-kubernetes.sh << 'EOF'
#!/bin/bash
source /workspace/scripts/lib/common.sh

print_status "Installing Kubernetes development tools..."

# Install k3s
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--data-dir /workspace/k3s" sh -

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Configure kubeconfig
mkdir -p /workspace/developer/.kube
cp /etc/rancher/k3s/k3s.yaml /workspace/developer/.kube/config
chown developer:developer /workspace/developer/.kube/config

print_success "Kubernetes environment ready"
EOF
```

## Monitoring and Observability

### Application Monitoring

**Monitoring Stack Setup:**

```bash
# Install monitoring tools
cat > /workspace/scripts/extensions.d/60-monitoring.sh << 'EOF'
#!/bin/bash
source /workspace/scripts/lib/common.sh

print_status "Setting up monitoring stack..."

# Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v3.5.0/prometheus-3.5.0.linux-amd64.tar.gz
tar xvfz prometheus-*.tar.gz
mv prometheus-*/prometheus /usr/local/bin/
mv prometheus-*/promtool /usr/local/bin/

# Node Exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.9.1/node_exporter-1.9.1.linux-amd64.tar.gz
tar xvfz node_exporter-*.tar.gz
mv node_exporter-*/node_exporter /usr/local/bin/

# Grafana
apt install -y software-properties-common
add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
apt update
apt install grafana -y

systemctl enable grafana-server
systemctl start grafana-server

print_success "Monitoring stack ready"
EOF
```

### Log Aggregation

**Centralized Logging:**

```bash
# ELK stack for log aggregation
cat > /workspace/docker/monitoring/docker-compose.yml << 'EOF'
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:9.1.3
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    volumes:
      - /workspace/data/elasticsearch:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"

  kibana:
    image: docker.elastic.co/kibana/kibana:9.1.3
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch

  logstash:
    image: docker.elastic.co/logstash/logstash:9.1.3
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
    depends_on:
      - elasticsearch
EOF
```

## API Gateway and Microservices

### API Development

**API Gateway Setup:**

```bash
# Kong API Gateway
cat > /workspace/docker/api-gateway/docker-compose.yml << 'EOF'
version: '3.8'
services:
  kong:
    image: kong:latest
    environment:
      - KONG_DATABASE=off
      - KONG_DECLARATIVE_CONFIG=/kong/declarative/kong.yml
      - KONG_PROXY_ACCESS_LOG=/dev/stdout
      - KONG_ADMIN_ACCESS_LOG=/dev/stdout
    volumes:
      - ./kong.yml:/kong/declarative/kong.yml
    ports:
      - "8000:8000"
      - "8443:8443"
      - "8001:8001"
      - "8444:8444"
EOF
```

**Microservices Development:**

```bash
# Service mesh with development tooling
cat > /workspace/scripts/microservices-dev.sh << 'EOF'
#!/bin/bash
# Start microservices development environment

# Start API gateway
cd /workspace/docker/api-gateway && docker-compose up -d

# Start monitoring
cd /workspace/docker/monitoring && docker-compose up -d

# Start development services
cd /workspace/projects/active/user-service && npm run dev &
cd /workspace/projects/active/order-service && npm run dev &
cd /workspace/projects/active/payment-service && npm run dev &

echo "Microservices development environment started"
echo "API Gateway: http://localhost:8000"
echo "Monitoring: http://localhost:3000 (Grafana)"
echo "Logs: http://localhost:5601 (Kibana)"
EOF
```

These advanced features transform your remote development environment into a comprehensive platform capable of handling complex, enterprise-scale development scenarios while maintaining the simplicity and cost-effectiveness of the base setup.
