# Claude Code and Claude Flow on Fly.io

## A Complete Remote AI-Assisted Development Environment

This repository contains everything you need to set up a secure, cost-optimized remote development environment running Claude Code and Claude Flow on Fly.io infrastructure.

## 🌟 What You Get

- **Zero Local Installation**: All AI tools run on remote VMs
- **Cost Optimization**: Auto-suspend VMs with persistent storage (~$2-5/month)
- **IDE Integration**: Full VSCode and IntelliJ remote development support
- **Team Collaboration**: Shared or individual VMs with persistent volumes
- **Security**: SSH-based access with Fly.io's network isolation
- **Scalability**: Easily scale resources up or down as needed

## ⚡ Quick Start - 5 Minutes to Claude!

### Option 1: Automated Setup (Recommended) 🚀

Get up and running with a single command:

```bash
# Clone and run the automated setup
git clone https://github.com/pacphi/claude-flow-on-fly.git
cd claude-flow-on-fly
chmod +x scripts/*.sh

# Run the setup script
./scripts/vm-setup.sh --app-name my-claude-dev --region iad

# For performance workloads, use dedicated CPU
./scripts/vm-setup.sh --app-name my-claude-dev --cpu-kind performance --cpu-count 2 --memory 2048
```

That's it! The script handles everything. For detailed options, see our **[Quick Start Guide](docs/QUICKSTART.md)**.

### Option 2: Manual Setup

For advanced users who prefer manual configuration, see our **[Complete Setup Guide](docs/SETUP.md)**.

### Prerequisites

Before starting, you'll need:
- [Fly.io CLI](https://fly.io/docs/flyctl/install/) installed and authenticated
- [SSH keys](https://www.ssh.com/academy/ssh-keys) (the script will check for these)
- [Claude Max](https://www.anthropic.com/max) subscription or [Anthropic API key](https://console.anthropic.com/settings/keys)

## 📁 Repository Structure

```
├── CLAUDE.md                          # Project instructions for Claude
├── README.md                          # This file
├── Dockerfile                         # Development environment container
├── fly.toml                           # Fly.io configuration with auto-scaling
├── docker/                            # Docker-related configurations
│   ├── config/                        # Configuration files
│   │   ├── developer-sudoers          # Sudo permissions for developer
│   │   └── sshd_config                # SSH daemon configuration
│   ├── scripts/                       # Docker setup scripts
│   │   ├── create-welcome.sh          # Welcome message creator
│   │   ├── entrypoint.sh              # Container entrypoint
│   │   ├── install-nvm.sh             # Node Version Manager installer
│   │   ├── install-packages.sh        # System packages installer
│   │   ├── setup-bashrc.sh            # Bash configuration
│   │   ├── setup-user.sh              # User account setup
│   │   └── vm-configure.sh            # VM configuration script
│   ├── lib/                           # Shared utility libraries
│   │   ├── common.sh                  # Core functions and utilities
│   │   ├── workspace.sh               # Workspace management
│   │   ├── tools.sh                   # Tool installation functions
│   │   ├── git.sh                     # Git configuration utilities
│   │   └── extensions.d/              # Extension examples
│   └── templates/                     # Docker templates
│       └── health-check.sh            # Health check script
├── scripts/                           # VM management scripts
│   ├── vm-setup.sh                    # Initial VM deployment
│   ├── vm-teardown.sh                 # Clean VM and resource removal
│   ├── vm-suspend.sh                  # Cost-saving VM suspension
│   ├── vm-resume.sh                   # VM resumption
│   ├── cost-monitor.sh                # Usage and cost tracking
│   ├── volume-backup.sh               # Data backup
│   └── volume-restore.sh              # Data restoration
├── templates/                         # Configuration templates
│   ├── CLAUDE.md.template             # Project context template
│   ├── settings.json.template         # Claude Code hooks
│   └── ssh_config.template            # SSH configuration
└── docs/                              # Documentation and guides
    ├── QUICKSTART.md                  # Quick start guide
    ├── SETUP.md                       # Complete setup guide
    ├── TROUBLESHOOTING.md             # Comprehensive troubleshooting guide
    ├── VSCODE.md                      # VSCode remote development
    └── INTELLIJ.md                    # IntelliJ remote development
```

## 🔧 Customization and Extensions

### Adding Custom Tools

The environment supports custom tool installations via the extension system:

1. **Create Extension Script**
   ```bash
   # Create a script in the extensions directory
   cat > /workspace/scripts/extensions.d/50-mycustomtool.sh << 'EOF'
   #!/bin/bash
   # Custom tool installation
   source /workspace/scripts/lib/common.sh

   print_status "Installing my custom tool..."
   # Your installation commands here
   print_success "Custom tool installed"
   EOF

   chmod +x /workspace/scripts/extensions.d/50-mycustomtool.sh
   ```

2. **Run Configuration**
   ```bash
   # Extensions run automatically during configuration
   /workspace/scripts/vm-configure.sh

   # Or run only extensions
   /workspace/scripts/vm-configure.sh --extensions-only
   ```

### Extension Examples

**Install Rust toolchain:**
```bash
# Copy example and enable
cp /workspace/scripts/extensions.d/10-rust.sh.example \
   /workspace/scripts/extensions.d/10-rust.sh
```

**Install Go development tools:**
```bash
# Copy example and enable
cp /workspace/scripts/extensions.d/20-golang.sh.example \
   /workspace/scripts/extensions.d/20-golang.sh
```

**Install Docker utilities:**
```bash
# Copy example and enable
cp /workspace/scripts/extensions.d/30-docker.sh.example \
   /workspace/scripts/extensions.d/30-docker.sh
```

### Using Common Libraries

All scripts now share common utilities in `/workspace/scripts/lib/`:

```bash
#!/bin/bash
# Example: Using common libraries in your scripts
source /workspace/scripts/lib/common.sh

print_status "Starting my task..."
if command_exists my-tool; then
    print_success "Tool is available"
else
    print_error "Tool not found"
fi
```

**Available Libraries:**
- `common.sh` - Print functions, colors, and utilities
- `workspace.sh` - Workspace management functions
- `tools.sh` - Tool installation helpers
- `git.sh` - Git configuration utilities

## 🚀 Getting Started

After running the automated setup above, connect to your environment:

### Step 1: Connect Your IDE

**For VSCode:**
```bash
# Follow the detailed guide
open docs/VSCODE.md

# Quick connection
ssh developer@my-claude-dev.fly.dev -p 10022
```

**For IntelliJ:**
```bash
# Follow the detailed guide
open docs/INTELLIJ.md

# Use JetBrains Gateway for remote connection
```

### Step 2: Configure Environment (First Time Only)

```bash
# SSH into your VM
ssh developer@my-claude-dev.fly.dev -p 10022

# Run the configuration script
/workspace/scripts/vm-configure.sh

# This will:
# - Install Node.js, Claude Code, and Claude Flow
# - Set up Git configuration
# - Create workspace structure
# - Optionally install development tools
```

### Step 3: Start Developing

```bash
# Authenticate Claude Code
claude

# Create or navigate to your project
cd /workspace/projects/active/your-project

# Start coding with AI assistance
claude

# Or use Claude Flow for multi-agent development
npx claude-flow@alpha swarm "build a REST API"
```

## 💰 Cost Management

### Automatic Cost Optimization
- **Auto-suspend**: VMs automatically suspend when idle
- **Scale-to-zero**: No compute charges when not in use
- **Persistent volumes**: Keep your data while saving on compute

### Manual Cost Control
```bash
# Suspend VM manually
./scripts/vm-suspend.sh

# Resume VM
./scripts/vm-resume.sh

# Monitor costs and usage
./scripts/cost-monitor.sh
```

### Estimated Costs
- **Minimal usage**: ~$2-3/month (mostly storage)
- **Regular usage**: ~$5-8/month
- **Heavy usage**: ~$10-15/month
- **Always-on**: ~$30-50/month

## 🔒 Security Features

- **SSH-only access** with key authentication
- **No password authentication** enabled
- **Network isolation** via Fly.io private networking
- **Non-standard SSH port** (10022) to reduce attack surface
- **Automatic security updates** in container builds

## 📊 Monitoring and Maintenance

### Usage Tracking
```bash
# Check current status
./scripts/cost-monitor.sh --action status

# View usage history
./scripts/cost-monitor.sh --action history

# Export usage data
./scripts/cost-monitor.sh --action export --export-format csv --export-file usage.csv
```

### Backup and Restore
```bash
# Create backup
./scripts/volume-backup.sh

# Restore from backup
./scripts/volume-restore.sh --file backup_20250104_120000.tar.gz

# Sync entire workspace
./scripts/volume-backup.sh --action sync
```

## 🛠 Advanced Features

### Team Collaboration
- **Shared VMs**: Multiple developers on one VM
- **Individual VMs**: Separate VMs with shared data volumes
- **Claude Flow Swarm**: Multi-agent AI development coordination

### Custom Configuration
- **Project templates**: Pre-configured project structures
- **Claude hooks**: Automated code formatting and linting
- **Environment variables**: Secure secret management
- **Resource scaling**: Dynamic VM sizing based on workload

### Integration Examples
```bash
# Database integration
flyctl postgres create --name my-db
flyctl postgres attach my-db -a my-claude-dev

# Redis for caching
flyctl redis create --name my-cache
flyctl redis attach my-cache -a my-claude-dev

# Custom domains
flyctl certs create example.com -a my-claude-dev
```

## 📚 Documentation

- **[Quick Start Guide](docs/QUICKSTART.md)**: Fast-track setup using automated scripts
- **[Complete Setup Guide](docs/SETUP.md)**: Comprehensive manual setup walkthrough
- **[VSCode Setup](docs/VSCODE.md)**: Detailed VSCode remote development guide
- **[IntelliJ Setup](docs/INTELLIJ.md)**: JetBrains IDE remote development guide

## 🔧 Troubleshooting

### Common Issues

**VM won't start:**
```bash
flyctl status -a my-claude-dev
flyctl machine list -a my-claude-dev
flyctl machine restart <machine-id> -a my-claude-dev
```

**SSH connection fails:**
```bash
# Test SSH configuration
ssh -vvv developer@my-claude-dev.fly.dev -p 10022

# Check VM status
flyctl logs -a my-claude-dev
```

**Claude Code authentication issues:**
```bash
# Re-authenticate
ssh developer@my-claude-dev.fly.dev -p 10022
claude auth
```

### Getting Help

1. **Check the logs**: `flyctl logs -a your-app-name`
2. **Review the guides**: See detailed setup documentation
3. **Community support**: Fly.io community forums
4. **GitHub issues**: Report bugs and feature requests

## 🎯 Use Cases

### Individual Developers
- **Remote coding**: Code from anywhere with just a browser
- **Powerful VMs**: Access to better hardware than local machine
- **Cost control**: Pay only for what you use
- **AI assistance**: Claude Code and Flow for productivity

### Teams
- **Standardized environments**: Everyone works in identical setups
- **Collaboration**: Shared projects and configurations
- **Onboarding**: New team members productive immediately
- **Resource sharing**: Efficient use of development resources

### Education
- **Classroom environments**: Consistent setup for all students
- **No local installation**: Students focus on learning, not setup
- **Cost-effective**: Schools pay only for actual usage
- **AI learning**: Students learn with AI assistance

## 🛣 Roadmap

- [ ] **Multi-region deployment** for global teams
- [ ] **Automated testing** integration
- [ ] **CI/CD pipeline** templates
- [ ] **Docker Compose** support for complex applications
- [ ] **GPU support** for AI/ML workloads
- [ ] **Pre-built templates** for popular frameworks

## 🤝 Contributing

Contributions are welcome! Please see our contributing guidelines:

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/amazing-feature`
3. **Make changes** and test thoroughly
4. **Commit with conventional commits**: `feat: add amazing feature`
5. **Push and create pull request**

## 📄 License

This project is licensed under the MIT License. See LICENSE file for details.

## 🙏 Acknowledgments

- **Anthropic**: For Claude Code and Claude AI
- **Fly.io**: For excellent container hosting platform
- **Community**: For feedback and contributions

---

## Quick Reference

### Essential Commands

```bash
# VM Management
flyctl status -a my-claude-dev                # Check status
flyctl machine list -a my-claude-dev          # List machines
flyctl logs -a my-claude-dev                  # View logs

# Cost Management
./scripts/vm-suspend.sh                       # Suspend VM
./scripts/vm-resume.sh                        # Resume VM
./scripts/cost-monitor.sh                     # Monitor usage

# Data Management
./scripts/volume-backup.sh                    # Backup data
./scripts/volume-restore.sh                   # Restore data

# Teardown
./scripts/vm-teardown.sh --app-name my-claude-dev          # Remove VM and volumes
./scripts/vm-teardown.sh --app-name my-claude-dev --backup # Backup then remove

# Development
ssh developer@my-claude-dev.fly.dev -p 10022  # Connect via SSH
claude                                        # Start Claude Code
npx claude-flow@alpha --help                  # Claude Flow help
```

### Important Paths

- **Workspace**: `/workspace` (persistent volume)
- **Projects**: `/workspace/projects/active/`
- **Scripts**: `/workspace/scripts/`
- **Backups**: `/workspace/backups/`
- **Config**: `/workspace/.config/`

### Configuration Files

- **Fly.io**: [fly.toml](fly.toml)
- **Docker**: [Dockerfile](Dockerfile)
- **SSH**: `~/.ssh/config`
- **Claude**: `/workspace/CLAUDE.md`
- **Hooks**: `~/.claude/settings.json`

Start building amazing things with AI-assisted development on Fly.io! 🚀
