# Claude Code and Claude Flow on Fly.io

A complete remote AI-assisted development environment running Claude Code and Claude Flow on Fly.io infrastructure with zero local installation, auto-suspend VMs, and persistent storage.

## ⚡ Quick Start

```bash
# Clone and deploy
git clone https://github.com/pacphi/claude-flow-on-fly.git
cd claude-flow-on-fly
./scripts/vm-setup.sh --app-name my-claude-dev --region iad

# Connect and configure
ssh developer@my-claude-dev.fly.dev -p 10022
./scripts/vm-configure.sh

# Start developing
claude
```

**Prerequisites**: [Fly.io CLI](https://fly.io/docs/flyctl/install/) + SSH keys + [Claude Max](https://www.anthropic.com/max) or [API key](https://console.anthropic.com/settings/keys)

## 📚 Documentation

- **[Quick Start Guide](docs/QUICKSTART.md)** - Fast setup using automated scripts
- **[Complete Setup](docs/SETUP.md)** - Manual setup walkthrough
- **[Architecture](docs/ARCHITECTURE.md)** - System architecture and file structure
- **[Cost Management](docs/COST_MANAGEMENT.md)** - Optimization strategies and monitoring
- **[Customization](docs/CUSTOMIZATION.md)** - Extensions, tools, and configuration
- **[Security](docs/SECURITY.md)** - Security features and best practices
- **[Advanced Features](docs/ADVANCED_FEATURES.md)** - Integrations and complex setups
  - **[Turbo Flow](docs/TURBO_FLOW.md)** - Features heavily borrowed from [turbo-flow-claude](https://github.com/marcuspat/turbo-flow-claude)
- **[Contributing](docs/CONTRIBUTING.md)** - Contribution guidelines and roadmap
- **[Reference](docs/REFERENCE.md)** - Complete command and configuration reference
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

### IDE Setup

- **[VSCode](docs/VSCODE.md)** - Remote development setup
- **[IntelliJ](docs/INTELLIJ.md)** - JetBrains Gateway configuration

## 🌟 Key Features

- **Zero Local Setup** - All AI tools run on remote VMs
- **Cost Optimized** - Auto-suspend VMs (from ~$1.70-8.70/month depending on configuration and usage)
- **IDE Integration** - VSCode and IntelliJ remote development
- **Team Ready** - Shared or individual VMs with persistent volumes
- **Secure** - SSH access with Fly.io network isolation
- **Scalable** - Dynamic resource allocation

## 🚀 Getting Started

1. **Deploy VM**: Run automated setup script
2. **Connect IDE**: Use VSCode Remote-SSH or IntelliJ Gateway
3. **Configure**: One-time environment setup
4. **Develop**: Start coding with AI assistance

See [Quick Start Guide](docs/QUICKSTART.md) for detailed walkthrough.

## 💰 Cost Management

VMs auto-suspend when idle for optimal cost efficiency.

Manual controls:

```bash
./scripts/vm-suspend.sh    # Suspend to save costs
./scripts/vm-resume.sh     # Resume when needed
./scripts/cost-monitor.sh  # Track usage
```

> [!TIP]
> See the cost management [guide]((docs/COST_MANAGEMENT.md)) for optimization strategies.

## 🔧 Essential Commands

```bash
# VM Management
flyctl status -a my-claude-dev
./scripts/vm-teardown.sh --app-name my-claude-dev

# Development
ssh developer@my-claude-dev.fly.dev -p 10022
claude
```

Full [command reference](docs/REFERENCE.md).

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Anthropic](https://www.anthropic.com/) for Claude Code and Claude AI
- [Reuven Cohen](https://www.linkedin.com/in/reuvencohen/) for [Claude Flow](https://github.com/ruvnet/claude-flow)
- [Fly.io](https://fly.io/) for an excellent container hosting platform
