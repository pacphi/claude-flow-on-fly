# Quick Start

Get your Claude development environment running in 5 minutes.

## Prerequisites

1. **[Fly.io CLI](https://fly.io/docs/flyctl/install/)** installed
2. **[Fly.io account](https://fly.io/signup)** (free tier available)
3. **SSH key pair** ([create one](TROUBLESHOOTING.md#creating-and-managing-ssh-keys))
4. **Claude Max** subscription OR **[API key](https://console.anthropic.com/settings/keys)**

## Deploy VM

```bash
# Clone and setup
git clone https://github.com/pacphi/claude-flow-on-fly.git
cd claude-flow-on-fly
chmod +x scripts/*.sh

# Deploy (takes ~3 minutes)
./scripts/vm-setup.sh --app-name my-claude-dev --region iad
```

The script automatically creates VM, storage, and SSH access.

## Connect

```bash
ssh developer@my-claude-dev.fly.dev -p 10022
```

For IDE setup, see [IDE Setup Guide](IDE_SETUP.md) first, then [VSCode](VSCODE.md) or [IntelliJ](INTELLIJ.md).

## First-Time Configuration

Run once after connecting:

```bash
/workspace/scripts/vm-configure.sh
```

This installs Node.js and Claude Code.
Claude Flow, Agentic Flow, and curated development tools get installed when you create new or clone existing projects.

## Start Using Claude

```bash
# Authenticate Claude Code
claude

# Create a project
cd /workspace/projects/active
mkdir my-project && cd my-project

# Initialize Claude Flow
npx claude-flow@alpha init --force
```

## Essential Commands

```bash
# Lifecycle management
./scripts/vm-suspend.sh     # Save costs when not using
./scripts/vm-resume.sh       # Resume work
./scripts/cost-monitor.sh    # Check usage

# If issues arise
flyctl status -a my-claude-dev
flyctl logs -a my-claude-dev
```

## Next Steps

- [Command Reference](REFERENCE.md) - All available commands
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions
- [Cost Management](COST_MANAGEMENT.md) - Optimization strategies

**Ready?** Run `./scripts/vm-setup.sh` and start coding with Claude! 🚀
