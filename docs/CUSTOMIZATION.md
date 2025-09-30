# Customization

## Extension System

The environment supports extensive customization through a modular extension system that allows you to add tools,
configure environments, and automate setup tasks.

## Adding Custom Tools

### Extension Script Structure

Extensions are shell scripts placed in `/workspace/scripts/extensions.d/` that run during environment configuration:

```bash
#!/bin/bash
# /workspace/scripts/extensions.d/50-mycustomtool.sh

# Load common utilities
source /workspace/scripts/lib/common.sh

print_status "Installing my custom tool..."

# Your installation commands here
curl -sSL https://example.com/install.sh | bash
export PATH="$PATH:/usr/local/bin/mycustomtool"

# Persist PATH changes
echo 'export PATH="$PATH:/usr/local/bin/mycustomtool"' >> /workspace/developer/.bashrc

print_success "Custom tool installed"
```

### Extension Execution Order

Extensions run in alphabetical order with phase-based prefixes:

- **pre-*** - Setup tasks that must run first
- **01-04*** - Core tool installations
- **05-70*** - Language-specific tools
- **80-90*** - Infrastructure and development tools
- **post-*** - Cleanup and finalization tasks

### Creating Extensions

**Create a new extension:**

```bash
# Create script file
cat > /workspace/scripts/extensions.d/50-mycustomtool.sh << 'EOF'
#!/bin/bash
source /workspace/scripts/lib/common.sh

print_status "Installing custom tool..."
# Installation commands
print_success "Custom tool ready"
EOF

# Make executable
chmod +x /workspace/scripts/extensions.d/50-mycustomtool.sh

# Run just your new extension (if it's activated)
/workspace/scripts/vm-configure.sh --extension mycustomtool

# Or run all extensions
/workspace/scripts/vm-configure.sh --extensions-only
```

### Extension Manager Utility

The `extension-manager.sh` utility in `/workspace/docker/lib/` provides comprehensive management for activating
and deactivating extensions:

**List all available extensions:**

```bash
# Show all extensions and their activation status
/workspace/docker/lib/extension-manager.sh list

# Example output:
# Available extensions in /workspace/scripts/extensions.d:
#
#   ✓ python (05-python.sh) - activated
#   ○ rust (10-rust.sh.example) - not activated
#   ○ golang (20-golang.sh.example) - not activated
#   ✓ docker (30-docker.sh) - activated
```

**Activate a single extension:**

```bash
# Activate Rust toolchain
/workspace/docker/lib/extension-manager.sh activate rust

# Activate Python development tools
/workspace/docker/lib/extension-manager.sh activate python

# Activate Docker utilities
/workspace/docker/lib/extension-manager.sh activate docker
```

**Deactivate a single extension:**

```bash
# Deactivate with confirmation prompt
/workspace/docker/lib/extension-manager.sh deactivate golang

# Deactivate without confirmation
/workspace/docker/lib/extension-manager.sh deactivate golang --yes

# Deactivate and create backup (automatic for modified extensions)
/workspace/docker/lib/extension-manager.sh deactivate python --backup --yes
```

**Activate all extensions:**

```bash
# Activate all available extensions at once
/workspace/docker/lib/extension-manager.sh activate-all

# Summary output shows:
#   Activated: 6
#   Skipped (already active): 2
#   Failed: 0
```

**Deactivate all non-protected extensions:**

```bash
# Deactivate all with confirmation
/workspace/docker/lib/extension-manager.sh deactivate-all

# Deactivate all without confirmation, creating backups
/workspace/docker/lib/extension-manager.sh deactivate-all --backup --yes
```

**Running individual extensions after activation:**

```bash
# Run a specific activated extension by name
/workspace/scripts/vm-configure.sh --extension rust
/workspace/scripts/vm-configure.sh --extension python

# Run the extension file directly
/workspace/scripts/extensions.d/10-rust.sh

# Run all activated extensions without full VM configuration
/workspace/scripts/vm-configure.sh --extensions-only
```

> [!TIP]
> Use `--extension <name>` to run just one activated extension without re-running all others. If the extension
> isn't activated, you'll receive instructions on how to activate it using the extension-manager.
> [!NOTE]
> Extensions 01-04 are core system components (marked as `[PROTECTED]`) and cannot be deactivated. Modified
> extensions automatically create backups when deactivated.

## Using Common Libraries

All extensions have access to shared utilities:

### Core Functions (`common.sh`)

```bash
source /workspace/scripts/lib/common.sh

# Output functions
print_status "Installing tool..."
print_success "Tool installed"
print_error "Installation failed"
print_warning "Optional step skipped"

# Utility functions
if command_exists docker; then
    print_success "Docker is available"
fi

if is_root; then
    print_error "Don't run as root"
    exit 1
fi

# Package management
install_apt_package curl wget git
install_npm_global typescript eslint
install_pip_package requests flask
```

### Tool Installation (`tools.sh`)

```bash
source /workspace/scripts/lib/tools.sh
```

### Workspace Management (`workspace.sh`)

```bash
source /workspace/scripts/lib/workspace.sh
```

## Configuration Examples

### Custom Development Environment

**Full-stack JavaScript:**

```bash
#!/bin/bash
# /workspace/scripts/extensions.d/15-fullstack-js.sh
source /workspace/scripts/lib/common.sh
source /workspace/scripts/lib/tools.sh

print_status "Setting up full-stack JavaScript environment..."

# Node.js with latest LTS
install_nodejs_latest

# Global packages
install_npm_global \
    typescript \
    '@typescript-eslint/parser' \
    '@typescript-eslint/eslint-plugin' \
    prettier \
    nodemon \
    pm2 \
    create-react-app \
    create-next-app \
    '@nestjs/cli'

# Database tools
install_apt_package postgresql-client redis-tools

print_success "Full-stack JavaScript environment ready"
```

**Data Science Setup:**

```bash
#!/bin/bash
# /workspace/scripts/extensions.d/25-datascience.sh
source /workspace/scripts/lib/common.sh
source /workspace/scripts/lib/tools.sh

print_status "Setting up data science environment..."

# Python with pyenv
install_pyenv
pyenv install 3.11.0
pyenv global 3.11.0

# Core packages
install_pip_package \
    jupyter \
    pandas \
    numpy \
    matplotlib \
    seaborn \
    scikit-learn \
    tensorflow \
    torch

# Jupyter setup
jupyter notebook --generate-config
echo "c.NotebookApp.ip = '0.0.0.0'" >> /workspace/developer/.jupyter/jupyter_notebook_config.py

print_success "Data science environment ready"
```

### Agent Configuration

To customize AI agent sources and behavior visit [agents-config.yaml](../docker/config/agents-config.yaml)

> [!Note]
> If you're curious about what is facilitating agent curation, visit [pacphi/claude-code-agent-manager](https://github.com/pacphi/claude-code-agent-manager).

### Tmux Workspace

Customize development workspace layout:

```bash
#!/bin/bash
# /workspace/scripts/extensions.d/35-custom-tmux.sh
source /workspace/scripts/lib/common.sh

print_status "Setting up custom tmux workspace..."

# Custom tmux configuration
cat > /workspace/developer/.tmux.conf << 'EOF'
# Custom key bindings
bind-key r source-file ~/.tmux.conf \; display-message "Config reloaded"
bind-key | split-window -h
bind-key - split-window -v

# Custom status bar
set -g status-bg colour235
set -g status-fg colour136
set -g status-left '#[fg=colour166]#S #[fg=colour245]|'
set -g status-right '#[fg=colour245]%Y-%m-%d %H:%M'

# Window numbering
set -g base-index 1
setw -g pane-base-index 1
EOF

# Custom workspace launcher
cat > /workspace/scripts/lib/my-workspace.sh << 'EOF'
#!/bin/bash
# Custom workspace layout

SESSION_NAME="dev-workspace"

# Create session if it doesn't exist
if ! tmux has-session -t $SESSION_NAME 2>/dev/null; then
    # Main development session
    tmux new-session -d -s $SESSION_NAME -n main

    # Code editing window
    tmux new-window -t $SESSION_NAME -n code
    tmux send-keys -t $SESSION_NAME:code "cd /workspace/projects/active" Enter

    # Server/build window
    tmux new-window -t $SESSION_NAME -n server
    tmux send-keys -t $SESSION_NAME:server "cd /workspace/projects/active" Enter

    # Git/terminal window
    tmux new-window -t $SESSION_NAME -n git
    tmux send-keys -t $SESSION_NAME:git "cd /workspace/projects/active" Enter

    # Select main window
    tmux select-window -t $SESSION_NAME:main
fi

# Attach to session
tmux attach-session -t $SESSION_NAME
EOF

chmod +x /workspace/scripts/lib/my-workspace.sh

print_success "Custom tmux workspace ready"
```

## Environment Variables

### Setting Development Variables

**Project-specific variables:**

```bash
# Create environment file
cat > /workspace/projects/active/my-app/.env << 'EOF'
NODE_ENV=development
API_URL=http://localhost:3000
DATABASE_URL=postgresql://localhost:5432/myapp
REDIS_URL=redis://localhost:6379
EOF

# Load automatically in shell
echo 'if [ -f .env ]; then export $(cat .env | xargs); fi' >> /workspace/developer/.bashrc
```

**Global development variables:**

```bash
# Add to bashrc for all projects
cat >> /workspace/developer/.bashrc << 'EOF'
export EDITOR=code
export PAGER=less
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
EOF
```

### Secret Management

**Using Fly.io secrets:**

```bash
# Set secrets at deployment time
flyctl secrets set OPENAI_API_KEY=sk-... -a my-claude-dev
flyctl secrets set GITHUB_TOKEN=ghp_... -a my-claude-dev
flyctl secrets set PERPLEXITY_API_KEY=pplx-... -a my-claude-dev
flyctl secrets set DATABASE_PASSWORD=secret123 -a my-claude-dev

# Access in scripts
echo $OPENAI_API_KEY  # Available as environment variable
```

## IDE Customization

### VSCode Settings

**Workspace settings:**

```json
// /workspace/projects/active/my-app/.vscode/settings.json
{
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
        "source.fixAll.eslint": true
    },
    "typescript.preferences.importModuleSpecifier": "relative",
    "files.associations": {
        "*.css": "postcss"
    }
}
```

**Remote development settings:**

```json
// ~/.vscode-server/data/Machine/settings.json
{
    "terminal.integrated.shell.linux": "/bin/bash",
    "remote.SSH.remotePlatform": {
        "my-claude-dev.fly.dev": "linux"
    },
    "workbench.colorTheme": "Dark+ (default dark)",
    "editor.minimap.enabled": false
}
```

### Claude Code Hooks

**Automated code formatting:**

```json
// /workspace/developer/.claude/settings.json
{
    "hooks": {
        "user-prompt-submit": "prettier --write .",
        "tool-use-start": "git add -A",
        "tool-use-end": "npm run lint --fix"
    },
    "outputStyles": {
        "default": {
            "codeBlock": {
                "showLineNumbers": true,
                "theme": "github-dark"
            }
        }
    }
}
```

## Project Templates

### Creating Custom Templates

**Template directory structure:**

```bash
mkdir -p /workspace/templates/my-stack
cd /workspace/templates/my-stack

# Project structure
mkdir -p src tests docs config
touch src/index.js tests/index.test.js README.md

# Package.json template
cat > package.json << 'EOF'
{
    "name": "{{PROJECT_NAME}}",
    "version": "1.0.0",
    "scripts": {
        "dev": "nodemon src/index.js",
        "test": "jest",
        "lint": "eslint src/"
    }
}
EOF

# Configuration files
cp /workspace/templates/common/.eslintrc.js .
cp /workspace/templates/common/.gitignore .
```

### CI/CD Integration

**GitHub Actions Setup:**

```bash
#!/bin/bash
# /workspace/scripts/extensions.d/60-github-actions.sh
source /workspace/scripts/lib/common.sh

print_status "Setting up GitHub Actions development tools..."

# Install Act for local testing
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# GitHub CLI for workflow management
if ! command_exists gh; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    apt update && apt install gh -y
fi

# Create GitHub Actions templates
mkdir -p /workspace/templates/github-workflows

cat > /workspace/templates/github-workflows/remote-dev-test.yml << 'EOF'
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
EOF

cat > /workspace/templates/github-workflows/deploy.yml << 'EOF'
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
EOF

print_success "GitHub Actions tools ready"
```

### Kubernetes Development

**Local Kubernetes Setup:**

```bash
#!/bin/bash
# /workspace/scripts/extensions.d/70-kubernetes.sh
source /workspace/scripts/lib/common.sh

print_status "Installing Kubernetes development tools..."

# Install k3s lightweight Kubernetes
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
```

### Monitoring and Observability

**Monitoring Stack Setup:**

```bash
#!/bin/bash
# /workspace/scripts/extensions.d/75-monitoring.sh
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

# Create Docker Compose for ELK stack
mkdir -p /workspace/docker/monitoring
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

print_success "Monitoring stack ready"
```

This comprehensive customization system allows you to tailor the development environment to your specific needs
while maintaining consistency and automation.
