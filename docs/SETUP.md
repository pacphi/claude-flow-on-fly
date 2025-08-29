# Getting Started with Claude Code and Claude Flow on Fly.io

## A Complete Guide to Remote AI-Assisted Development

> **🚀 Quick Start Available!** New users should start with our [Quick Start Guide](QUICKSTART.md) which uses the automated `vm-setup.sh` script for the fastest setup experience. This guide provides detailed manual setup instructions for advanced users or troubleshooting.

This guide provides comprehensive instructions for setting up a secure, cost-optimized remote development environment on Fly.io with Claude Code and Claude Flow. Unlike traditional setups, this approach installs all AI tools on the remote VM, with developers connecting via their preferred IDE's remote development features.

## Table of Contents

1. [Introduction](#introduction)
2. [Architecture Overview](#architecture-overview)
3. [Prerequisites](#prerequisites)
4. [Cost Overview](#cost-overview)
5. [Automated Setup (Recommended)](#automated-setup-recommended)
6. [Manual Setup (Advanced)](#manual-setup-advanced)
7. [Persistent Volume Management](#persistent-volume-management)
8. [IDE Remote Connection](#ide-remote-connection)
9. [Memory Management](#memory-management)
10. [Cost Optimization](#cost-optimization)
11. [Team Collaboration](#team-collaboration)
12. [Security Best Practices](#security-best-practices)
13. [Troubleshooting](#troubleshooting)

## Introduction

This setup enables AI-assisted development using Claude Code and Claude Flow on Fly.io virtual machines, providing:

- **Zero Local Installation**: All tools run on the remote VM
- **Cost Efficiency**: Scale-to-zero capabilities with persistent storage
- **Team Collaboration**: Shared or individual VMs with persistent volumes
- **Security**: SSH-based access with Fly.io's network isolation
- **IDE Integration**: Full VSCode or IntelliJ functionality via remote connections

## Architecture Overview

```text
┌─────────────────┐     SSH/Remote      ┌──────────────────┐
│ Developer IDE   │ ◄─────────────────► │ Fly.io VM        │
│(VSCode/IntelliJ)│                     │ - Claude Code    │
└─────────────────┘                     │ - Claude Flow    │
                                        │ - Project Files  │
                                        └──────┬───────────┘
                                               │
                                        ┌──────▼───────────┐
                                        │ Persistent       │
                                        │ Volume (10GB)    │
                                        │ - Source Code    │
                                        │ - Dependencies   │
                                        │ - Claude Memory  │
                                        └──────────────────┘
```

### Key Components

1. **Fly.io VM**: Ubuntu-based container running Claude tools
2. **Persistent Volume**: Survives VM restarts, stores all project data
3. **Auto-stop/Start**: VM suspends when idle, resumes on connection
4. **Remote IDE**: VSCode or IntelliJ connects via SSH

## Prerequisites

### On Your Local Machine

- [Fly.io](https://fly.io/) [CLI](https://fly.io/docs/flyctl/install/) (`flyctl`) installed
- VSCode with [Remote-SSH](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh) extension OR IntelliJ with [remote development support]((https://www.jetbrains.com/remote-development/gateway/))
- SSH key pair for authentication
- Active Fly.io account

### Subscriptions Required

- Fly.io account (Hobby plan includes 3GB free storage)
- [Claude Max](https://www.anthropic.com/max) subscription OR Anthropic [API key]((https://console.anthropic.com/settings/keys))
- (Optional) Claude Flow license if using advanced features

## Cost Overview

### Estimated Monthly Costs

**Minimal Setup (Hobby/Individual)**

- VM (1GB RAM, 1 shared CPU): ~$5/month when running
- Persistent Volume (10GB): $1.50/month
- With auto-stop: ~$2-3/month total

**Performance Setup (Intensive Development)**

- VM (2GB RAM, 2 shared CPUs): ~$10/month when running
- VM (2GB RAM, 1 performance CPU): ~$15/month when running
- Persistent Volume (20GB): $3/month
- With auto-stop: ~$5-8/month total

**Team Setup (Small team)**

- VM (4GB RAM, 2 performance CPUs): ~$30/month when running
- Persistent Volume (50GB): $7.50/month
- With auto-stop: ~$10-15/month total

**Note**: Storage costs persist even when VM is stopped. Only compute costs stop.

## Automated Setup (Recommended)

The fastest way to get started is using the automated setup script:

```bash
# Clone the repository
git clone https://github.com/pacphi/claude-flow-on-fly.git
cd claude-flow-on-fly

# Make scripts executable
chmod +x scripts/*.sh

# Run the automated setup
./scripts/vm-setup.sh --app-name my-claude-dev --region iad
```

### What the Script Does

The `vm-setup.sh` script automates the entire initial setup:

1. ✅ **Validates prerequisites** - Checks for flyctl, SSH keys, and required files
2. ✅ **Creates Fly.io application** - Sets up your app in the specified region
3. ✅ **Creates persistent volume** - Configures storage for your code and data
4. ✅ **Configures SSH access** - Sets up secure key-based authentication
5. ✅ **Deploys the environment** - Builds and deploys your development VM
6. ✅ **Shows connection info** - Provides SSH commands and configuration

### Script Options

```bash
./scripts/vm-setup.sh [OPTIONS]

Options:
  --app-name NAME     Name for the Fly.io app (default: claude-dev-env)
  --region REGION     Fly.io region (default: iad)
  --volume-size SIZE  Volume size in GB (default: 10)
  --memory SIZE       VM memory in MB (default: 1024)
  --help              Show help message

Examples:
  # Basic setup
  ./scripts/vm-setup.sh

  # Custom configuration
  ./scripts/vm-setup.sh --app-name my-dev --region sjc --volume-size 20

  # With API key
  ANTHROPIC_API_KEY=sk-ant-... ./scripts/vm-setup.sh --app-name claude-dev
```

After the script completes, skip to [IDE Remote Connection](#ide-remote-connection) to connect to your environment.

## Manual Setup (Advanced)

### Step 1: Create Fly.io Application

```bash
# Create a new directory for your Fly.io configuration
mkdir claude-dev-env && cd claude-dev-env

# Initialize Fly.io app
flyctl launch --no-deploy \
  --name my-claude-dev \
  --region iad \
  --vm-memory 1024

# This creates a fly.toml file
```

### Step 2: Create Persistent Volume

```bash
# Create a 10GB volume in the same region
flyctl volumes create claude_data \
  --region iad \
  --size 10 \
  --no-encryption

# List volumes to confirm
flyctl volumes list
```

> [!IMPORTANT]
> VM and Persistent Volume region configuration should be consistent. Consult https://fly.io/docs/reference/regions/ for available regions.

### Step 3: Configure fly.toml

Edit the generated `fly.toml` file:

```toml
app = "my-claude-dev"
primary_region = "iad"

[build]
  dockerfile = "Dockerfile"

[env]
  # User for SSH access
  DEV_USER = "developer"
  # Port for SSH (internal)
  SSH_PORT = "22"

[mounts]
  source = "claude_data"
  destination = "/workspace"

[[services]]
  internal_port = 22
  protocol = "tcp"
  auto_stop_machines = "suspend"
  auto_start_machines = true
  min_machines_running = 0

  [[services.ports]]
    port = 10022

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = "suspend"
  auto_start_machines = true
  min_machines_running = 0
```

### Step 4: Create Dockerfile

Create a `Dockerfile` in the same directory:

```dockerfile
FROM ubuntu:22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    openssh-server \
    sudo \
    curl \
    git \
    vim \
    build-essential \
    python3 \
    python3-pip \
    nodejs \
    npm \
    tmux \
    htop \
    && rm -rf /var/lib/apt/lists/*

# Create developer user
RUN useradd -m -s /bin/bash -G sudo developer && \
    echo "developer:developer" | chpasswd && \
    echo "developer ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/developer

# Configure SSH
RUN mkdir /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Create workspace directory (will be mounted)
RUN mkdir -p /workspace && chown developer:developer /workspace

# Switch to developer user
USER developer
WORKDIR /home/developer

# Create SSH directory
RUN mkdir -p ~/.ssh && chmod 700 ~/.ssh

# Copy authorized keys (will be set via secrets)
RUN touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys

# Install Node Version Manager (nvm) for developer user
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash && \
    echo 'export NVM_DIR="$HOME/.nvm"' >> ~/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc && \
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> ~/.bashrc

# Pre-create Claude configuration directory
RUN mkdir -p ~/.claude

# Switch back to root for startup script
USER root

# Create startup script
RUN echo '#!/bin/bash\n\
# Add SSH keys from environment\n\
if [ ! -z "$AUTHORIZED_KEYS" ]; then\n\
    echo "$AUTHORIZED_KEYS" > /home/developer/.ssh/authorized_keys\n\
    chown developer:developer /home/developer/.ssh/authorized_keys\n\
    chmod 600 /home/developer/.ssh/authorized_keys\n\
fi\n\
# Ensure workspace permissions\n\
chown -R developer:developer /workspace\n\
# Start SSH service\n\
/usr/sbin/sshd -D' > /start.sh && chmod +x /start.sh

EXPOSE 22
CMD ["/start.sh"]
```

### Step 5: Set SSH Keys

```bash
# Set your public SSH key as a secret
flyctl secrets set AUTHORIZED_KEYS="$(cat ~/.ssh/id_rsa.pub)"
```

### Step 6: Deploy

```bash
# Deploy the application
flyctl deploy

# Check status
flyctl status

# Get connection info
flyctl info
```

## Persistent Volume Management

### Understanding Volume Behavior

- Volumes persist data between VM restarts
- Volumes are tied to specific hardware in a region
- Volume costs continue even when VM is stopped
- Automatic daily snapshots (retained for 5 days by default)

### Backup Strategy

Create a backup script on the VM (`/workspace/scripts/backup.sh`):

```bash
#!/bin/bash
# Backup critical data to external storage

BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/workspace/backups"
CRITICAL_DIRS="/workspace/projects /home/developer/.claude"

# Create backup directory
mkdir -p $BACKUP_DIR

# Create tarball of critical directories
tar -czf "$BACKUP_DIR/backup_$BACKUP_DATE.tar.gz" $CRITICAL_DIRS

# Keep only last 7 backups
find $BACKUP_DIR -name "backup_*.tar.gz" -mtime +7 -delete

echo "Backup completed: backup_$BACKUP_DATE.tar.gz"
```

### Volume Snapshots

```bash
# Create manual snapshot
flyctl volumes snapshots create vol_xxxx

# List snapshots
flyctl volumes snapshots list vol_xxxx
```

## IDE Remote Connection

### VSCode Setup

1. **Install Remote-SSH Extension**

   - Open VSCode
   - Install "Remote - SSH" extension from Microsoft

2. **Configure SSH**

   Add to `~/.ssh/config`:

   ```bash
   Host fly-claude-dev
       HostName my-claude-dev.fly.dev
       Port 10022
       User developer
       IdentityFile ~/.ssh/id_rsa
       ServerAliveInterval 60
       ServerAliveCountMax 3
   ```

3. **Connect to VM**

   - Open Command Palette (Cmd/Ctrl + Shift + P)
   - Select "Remote-SSH: Connect to Host"
   - Choose "fly-claude-dev"

### IntelliJ Setup

1. **Open JetBrains Gateway**

   - Download and install JetBrains Gateway
   - Click "New Connection"

2. **Configure SSH Connection**

   - Connection Type: SSH
   - Host: my-claude-dev.fly.dev
   - Port: 10022
   - Username: developer
   - Authentication: Key pair
   - Private key: Browse to ~/.ssh/id_rsa

3. **Select IDE and Project**

   - Choose your IDE (IntelliJ IDEA, etc.)
   - Project directory: /workspace/your-project

## First-Time Configuration

After connecting to your VM for the first time, you need to run the configuration script to set up your development environment:

### Run the Configuration Script

```bash
# Connect to VM via SSH or IDE terminal
/workspace/scripts/vm-configure.sh
```

This interactive script will:

- ✅ Install Node.js (latest LTS version)
- ✅ Install Claude Code and Claude Flow
- ✅ Set up Git configuration (name and email)
- ✅ Create workspace directory structure
- ✅ Create helpful utility scripts
- ✅ Set up Claude configuration files
- ✅ Optionally install additional development tools
- ✅ Optionally create project templates

### Configuration Options

During the script execution, you'll be prompted for:

1. **Git Configuration**

   - Your name for Git commits
   - Your email for Git commits

2. **Additional Development Tools** (optional)

   - TypeScript, ESLint, Prettier for JavaScript development
   - Black, Flake8 for Python development
   - Other helpful development utilities

3. **Project Templates** (optional)

   - Node.js project template
   - Python project template

### Skip Options

If you need to reconfigure later or skip certain parts:

```bash
# Run with interactive mode for all prompts
/workspace/scripts/vm-configure.sh --interactive

# Skip Claude tools installation (if already installed)
/workspace/scripts/vm-configure.sh --skip-claude

# Install tools for specific language
/workspace/scripts/vm-configure.sh --language rust

# Run only custom extensions
/workspace/scripts/vm-configure.sh --extensions-only
```

### Extending the Environment

#### Custom Tool Installation

You can extend the environment with custom tools by adding scripts to the extensions directory:

1. **Create Extension Script**

   ```bash
   # Create extensions directory if it doesn't exist
   mkdir -p /workspace/scripts/extensions.d/

   # Create your custom installation script
   cat > /workspace/scripts/extensions.d/50-mycustomtool.sh << 'EOF'
   #!/bin/bash
   source /workspace/scripts/lib/common.sh

   print_status "Installing my custom tool..."
   # Your installation commands here
   print_success "Custom tool installed"
   EOF

   chmod +x /workspace/scripts/extensions.d/50-mycustomtool.sh
   ```

2. **Run Configuration**

   ```bash
   /workspace/scripts/vm-configure.sh
   # Your extension will run automatically
   ```

3. **Available Examples**

   ```bash
   # Enable Rust toolchain
   cp /workspace/scripts/extensions.d/10-rust.sh.example \
      /workspace/scripts/extensions.d/10-rust.sh

   # Enable Go development tools
   cp /workspace/scripts/extensions.d/20-golang.sh.example \
      /workspace/scripts/extensions.d/20-golang.sh

   # Enable Docker utilities
   cp /workspace/scripts/extensions.d/30-docker.sh.example \
      /workspace/scripts/extensions.d/30-docker.sh
   ```

#### Using Shared Libraries

All management scripts now use shared libraries for consistency:

```bash
#!/bin/bash
# Example: Using common libraries in your own scripts
source /workspace/scripts/lib/common.sh

print_status "Starting my task..."
if command_exists my-tool; then
    print_success "Tool is available"
else
    print_error "Tool not found"
fi
```

**Available Libraries:**

- `common.sh` - Print functions, colors, command checking
- `workspace.sh` - Project creation, templates, backup scripts
- `tools.sh` - Tool installation (Node.js, Claude, language tools)
- `git.sh` - Git setup, aliases, hooks

#### Extension Execution Order

Extensions run in three phases during configuration:

1. **Pre-install** (`pre-*.sh`) - Before main tool installation
2. **Install** (`*.sh`) - During main installation phase
3. **Post-install** (`post-*.sh`) - After all tools are installed

Use numbered prefixes (10-, 20-, 30-) to control execution order within each phase.

### What Gets Created

After running the configuration script, you'll have:

```bash
/workspace/
├── projects/
│   ├── active/           # Your active projects
│   ├── archive/          # Archived projects
│   └── templates/        # Project templates (if selected)
├── scripts/
│   ├── backup.sh         # Backup workspace data
│   ├── restore.sh        # Restore from backup
│   ├── new-project.sh    # Create new project
│   └── system-status.sh  # Check system status
├── backups/              # Backup storage
└── .config/              # Configuration files
```

## Claude Tools Authentication

After the configuration script completes, Claude Code will be installed and Claude Flow will be available via npx. You just need to authenticate:

### Authenticate Claude Code

```bash
# Start Claude Code to authenticate
claude

# This will prompt for authentication
# Choose your preferred method:
# 1. Claude Max account (recommended for regular use)
# 2. Anthropic API key
```

### Initialize Claude Flow in Your Project

```bash
# Navigate to your project
cd /workspace/projects/active/your-project

# Initialize Claude Flow
npx claude-flow@alpha init --force

# This creates:
# - .claude/ directory
# - .swarm/ directory for memory
# - Configuration files
```

### Verify Installation

```bash
# Check Claude Code
claude --version

# Check Node.js and npm (required for Claude Flow)
node --version
npm --version

# Note: Claude Flow is not installed globally - it's run via npx
# Test Claude Flow availability:
npx claude-flow@alpha --help
```

## Memory Management

### Project Context with CLAUDE.md

Create `/workspace/your-project/CLAUDE.md`:

```markdown
# Project Context for Claude

## Project Overview
This is a [project type] built with [technologies].

## Key Commands

- Build: `npm run build`
- Test: `npm test`
- Lint: `npm run lint`

## Architecture Notes

- Main entry point: src/index.js
- Database: PostgreSQL on Fly.io
- API: RESTful endpoints in src/api/

## Development Workflow

1. Always run tests before committing
2. Use feature branches
3. Follow conventional commits

## Important Files

- Configuration: config/
- Database models: src/models/
- API routes: src/routes/

## Custom Instructions

- Use TypeScript for all new files
- Prefer functional programming patterns
- Add JSDoc comments to public APIs
```

### Global Preferences

Create `/home/developer/.claude/CLAUDE.md`:

```markdown
# Developer Preferences

## Code Style
- Indent with 2 spaces
- Use semicolons
- Prefer const over let

## Git Workflow
- Commit messages: conventional commits
- Branch naming: feature/description

## Testing
- Write tests for all new features
- Aim for 80% coverage
```

### Claude Flow Memory

Claude Flow maintains persistent memory in SQLite:

```bash
# View memory contents
sqlite3 /workspace/your-project/.swarm/memory.db

# In SQLite prompt
.tables
SELECT * FROM agent_memory LIMIT 10;
```

## Cost Optimization

### Auto-stop Configuration

The `fly.toml` configuration includes:

- `auto_stop_machines = "suspend"` - Suspends VM when idle
- `min_machines_running = 0` - Allows complete scale-to-zero
- `auto_start_machines = true` - Resumes on incoming connection

### Monitoring Usage

Create `/workspace/scripts/cost-monitor.sh`:

```bash
#!/bin/bash
# Monitor Fly.io usage

echo "=== Fly.io Usage Report ==="
echo "Current Status:"
flyctl status

echo -e "\nMachine Details:"
flyctl machine list

echo -e "\nVolume Usage:"
flyctl volumes list

echo -e "\nEstimated Costs:"
echo "- VM (when running): ~$0.0067/hour"
echo "- Volume (10GB): $0.15/GB/month = $1.50/month"
echo "- Current uptime this month: $(flyctl logs | grep 'Machine started' | wc -l) starts"
```

### Suspend/Resume Scripts

Create `/workspace/scripts/vm-suspend.sh`:

```bash
#!/bin/bash
# Gracefully suspend the VM

# Save any work
echo "Saving work state..."
tmux list-sessions 2>/dev/null && tmux send-keys -t 0 C-s

# Sync filesystem
sync

# Stop the machine
flyctl machine stop $(flyctl machine list --json | jq -r '.[0].id')
```

Create `/workspace/scripts/vm-resume.sh`:

```bash
#!/bin/bash
# Resume the VM

# Start the machine
flyctl machine start $(flyctl machine list --json | jq -r '.[0].id')

# Wait for SSH
echo "Waiting for SSH..."
while ! ssh -o ConnectTimeout=5 fly-claude-dev echo "Connected"; do
    sleep 2
done

echo "VM resumed and ready!"
```

## Team Collaboration

### Option 1: Shared VM

Multiple developers share one VM:

- Add all team SSH keys to `AUTHORIZED_KEYS`
- Use separate user directories or workspaces
- Coordinate via tmux sessions

```bash
# Add multiple SSH keys
flyctl secrets set AUTHORIZED_KEYS="$(cat key1.pub key2.pub key3.pub)"
```

### Option 2: Individual VMs with Shared Volume

Each developer has their own VM but shares data:

- Create separate apps for each developer
- Use Fly.io volume snapshots to sync
- Implement Git-based workflow

### Option 3: Claude Flow Swarm Mode

Leverage Claude Flow's multi-agent capabilities:

```bash
# Initialize swarm mode
npx claude-flow@alpha hive-mind wizard

# Configure agents for different team members
# Each agent can work on different parts of the codebase
```

## Security Best Practices

### SSH Security

1. **Key-only Authentication**

   - Password authentication is disabled
   - Use strong SSH keys (Ed25519 recommended)

2. **Regular Key Rotation**

   ```bash
   # Generate new key
   ssh-keygen -t ed25519 -f ~/.ssh/fly_claude_key

   # Update on Fly.io
   flyctl secrets set AUTHORIZED_KEYS="$(cat ~/.ssh/fly_claude_key.pub)"
   ```

3. **Network Security**

   - Fly.io provides network isolation
   - Use Fly.io private networking for database connections
   - Consider WireGuard for additional security

### API Key Management

1. **Never commit API keys**

   ```bash
   # Set as secrets
   flyctl secrets set ANTHROPIC_API_KEY="sk-ant-..."
   ```

2. **Use environment variables**

   ```bash
   # In VM startup script
   export ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY
   ```

### Data Protection

1. **Regular Backups**

   - Automated daily snapshots
   - Manual backups before major changes
   - Off-site backup to S3/GCS

2. **Encryption**

   - Use encrypted volumes for sensitive data
   - Encrypt backups before external storage

## Troubleshooting

For comprehensive troubleshooting information, see our dedicated [Troubleshooting Guide](TROUBLESHOOTING.md).

### Quick Reference - Common Issues

#### VM Won't Start

```bash
# Check logs
flyctl logs

# Check machine status
flyctl machine list

# Restart manually
flyctl machine restart <machine-id>
```

#### SSH Connection Failed

For detailed SSH troubleshooting including host key verification issues, permission problems, and connection debugging, see [SSH Connection Issues](TROUBLESHOOTING.md#ssh-connection-issues) in our Troubleshooting Guide.

**Quick SSH Debugging:**

```bash
# Test connection with verbose output
ssh -vvv developer@your-app-name.fly.dev -p 10022

# If you get host key verification failed after VM recreation:
ssh-keygen -R "[your-app-name.fly.dev]:10022"
```

#### Claude Code Authentication Issues

```bash
# Clear credentials
rm -rf ~/.claude/credentials

# Re-authenticate
claude auth

# Check API key (if using)
echo $ANTHROPIC_API_KEY
```

#### Volume Mount Issues

```bash
# Verify volume is attached
flyctl volumes list

# Check mount point
df -h | grep workspace

# Fix permissions
sudo chown -R developer:developer /workspace
```

### Performance Optimization

#### Slow IDE Connection

1. Check region proximity
2. Upgrade VM size if needed
3. Use mosh for unstable connections

#### Claude Code Response Time

1. Ensure adequate VM memory
2. Check network latency
3. Consider upgrading to dedicated CPU

### Getting Help

- **[Comprehensive Troubleshooting Guide](TROUBLESHOOTING.md)** - Detailed solutions for all common issues
- **[SSH Issues](TROUBLESHOOTING.md#ssh-connection-issues)** - SSH key management and connection problems
- **[VM Management](TROUBLESHOOTING.md#vm-management-issues)** - VM startup, suspension, and volume issues
- **[Performance](TROUBLESHOOTING.md#performance-issues)** - Optimization and speed improvements

1. **Fly.io Support**

   - Community: https://community.fly.io
   - Status: https://status.flyio.net

2. **Claude Code**

   - Documentation: https://docs.anthropic.com/claude-code
   - Issues: https://github.com/anthropics/claude-code/issues

3. **Claude Flow**

   - Repository: https://github.com/ruvnet/claude-flow
   - Documentation: See repository docs/

## Next Steps

1. **Customize Your Environment**

   - Install additional tools via Dockerfile
   - Configure your preferred shell and dotfiles
   - Set up project-specific CLAUDE.md

2. **Optimize Costs**

   - Monitor usage patterns
   - Adjust VM size based on needs
   - Implement aggressive auto-stop policies

3. **Scale Your Team**

   - Document team-specific workflows
   - Create onboarding scripts
   - Establish coding standards

---

## Quick Reference

### Essential Commands

```bash
# VM Management
flyctl status                    # Check VM status
flyctl logs                      # View logs
flyctl ssh console              # Direct SSH access

# Volume Management
flyctl volumes list             # List volumes
flyctl volumes snapshots list   # List snapshots

# Cost Monitoring
flyctl scale show              # Current scale settings
flyctl machine list            # Machine details

# Claude Tools
claude                         # Start Claude Code
npx claude-flow@alpha --help   # Claude Flow help
```

### Configuration Files

- `/fly.toml` - Fly.io configuration
- `/workspace/your-project/CLAUDE.md` - Project context
- `/home/developer/.claude/` - Claude configuration
- `/workspace/your-project/.swarm/` - Claude Flow memory

### Important Paths

- `/workspace/` - Persistent volume mount
- `/home/developer/` - User home (ephemeral)
- `~/.ssh/` - SSH configuration
- `~/.claude/` - Claude user settings

---

This guide provides a complete setup for remote AI-assisted development on Fly.io. Adjust configurations based on your specific needs and team size.
