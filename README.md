# Claude Code and Claude Flow on Fly.io

[![Version](https://img.shields.io/github/v/release/pacphi/claude-flow-on-fly?include_prereleases)](https://github.com/pacphi/claude-flow-on-fly/releases)
[![License](https://img.shields.io/github/license/pacphi/claude-flow-on-fly)](LICENSE)
[![Integration Tests](https://github.com/pacphi/claude-flow-on-fly/actions/workflows/integration.yml/badge.svg)](https://github.com/pacphi/claude-flow-on-fly/actions/workflows/integration.yml)

A complete remote AI-assisted development environment running Claude Code and Claude Flow on Fly.io infrastructure
with zero local installation, auto-suspend VMs, and persistent storage.

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

> **Prerequisites**: [Fly.io CLI](https://fly.io/docs/flyctl/install/) + SSH keys +
[Claude Max](https://www.anthropic.com/max) or [API key](https://console.anthropic.com/settings/keys)

## 📚 Documentation

- **[Quick Start Guide](docs/QUICKSTART.md)** - Fast setup using automated scripts
- **[Complete Setup](docs/SETUP.md)** - Manual setup walkthrough
- **[Architecture](docs/ARCHITECTURE.md)** - System architecture and file structure
- **[Cost Management](docs/COST_MANAGEMENT.md)** - Optimization strategies and monitoring
- **[Customization](docs/CUSTOMIZATION.md)** - Extensions, tools, and configuration
- **[Security](docs/SECURITY.md)** - Security features and best practices
- **[Agents](docs/AGENTS.md)** - Agent management, search, and development
- **[Turbo Flow](docs/TURBO_FLOW.md)** - Mimic enterprise AI development features from [turbo-flow-claude](https://github.com/marcuspat/turbo-flow-claude)
- **[Contributing](docs/CONTRIBUTING.md)** - Contribution guidelines and roadmap
- **[Reference](docs/REFERENCE.md)** - Complete command and configuration reference
- **[Troubleshooting](docs/TROUBLESHOOTING.md)** - Common issues and solutions

### IDE Setup

- **[IDE Setup Guide](docs/IDE_SETUP.md)** - Common setup for all IDEs
- **[VSCode](docs/VSCODE.md)** - VS Code-specific configuration
- **[IntelliJ](docs/INTELLIJ.md)** - JetBrains IDE-specific configuration

## 🌟 Key Features

- **Zero Local Setup** - All AI tools run on remote VMs
- **Cost Optimized** - Auto-suspend VMs (see [cost guide](docs/COST_MANAGEMENT.md) for details)
- **Multi-Model AI** - agent-flow integration for 85-99% cost savings with 100+ models
- **IDE Integration** - VSCode and IntelliJ remote development
- **Team Ready** - Shared or individual VMs with persistent volumes
- **Secure** - SSH access with Fly.io network isolation
- **Scalable** - Dynamic resource allocation

## 🚀 Getting Started

1. **Deploy VM**: Run automated setup script
2. **Connect IDE**: Use VSCode Remote-SSH or IntelliJ Gateway
3. **Configure**: One-time environment setup
4. **Develop**: Start coding with AI assistance

> See [Quick Start Guide](docs/QUICKSTART.md) for detailed walkthrough.

## 💰 Cost Management

VMs auto-suspend when idle for optimal cost efficiency.

Manual controls:

```bash
./scripts/vm-suspend.sh    # Suspend to save costs
./scripts/vm-resume.sh     # Resume when needed
./scripts/cost-monitor.sh  # Track usage
```

> See the [cost management guide](docs/COST_MANAGEMENT.md) for optimization strategies.

## 🔧 Essential Commands

```bash
# VM Management
flyctl status -a my-claude-dev
./scripts/vm-teardown.sh --app-name my-claude-dev

# Development
ssh developer@my-claude-dev.fly.dev -p 10022
claude
```

> Full [command reference](docs/REFERENCE.md).

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Anthropic](https://www.anthropic.com/) for Claude Code and Claude AI
- [Reuven Cohen](https://www.linkedin.com/in/reuvencohen/) for [Claude Flow](https://github.com/ruvnet/claude-flow) and
  [Agentic Flow](https://github.com/ruvnet/agentic-flow)
- [Fly.io](https://fly.io/) for an excellent container hosting platform
