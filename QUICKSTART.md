# 🚀 Quick Start Guide

Get your Claude development environment running on Fly.io in under 5 minutes!

## Prerequisites

Before you begin, ensure you have:

1. **[Fly.io CLI](https://fly.io/docs/flyctl/install/)** installed
2. **[Fly.io account](https://fly.io/signup)** (free tier available)
3. **SSH key pair** (if you don't have one, see [Creating SSH Keys](#creating-ssh-keys))
4. **[Claude Max](https://www.anthropic.com/max)** subscription OR **[Anthropic API key](https://console.anthropic.com/settings/keys)**

## ⚡ Automated Setup (Recommended)

The fastest way to get started is using our automated setup script:

```bash
# Clone the repository
git clone https://github.com/pacphi/claude-flow-on-fly.git
cd claude-flow-on-fly

# Make scripts executable
chmod +x scripts/*.sh

# Run the automated setup
./scripts/vm-setup.sh --app-name my-claude-dev --region iad
```

That's it! The script will:
✅ Create your Fly.io application
✅ Set up a persistent volume for your code
✅ Configure SSH access
✅ Deploy the development environment
✅ Show you connection instructions

### Setup Options

```bash
# Customize your setup
./scripts/vm-setup.sh \
  --app-name my-dev-env \     # Your app name (must be unique)
  --region sjc \               # Fly.io region (see https://fly.io/docs/reference/regions/)
  --volume-size 20 \           # Storage size in GB (default: 10)
  --memory 2048                # VM memory in MB (default: 1024)

# With API key (optional)
ANTHROPIC_API_KEY=sk-ant-... ./scripts/vm-setup.sh --app-name my-claude
```

## 🔌 Connect to Your Environment

After setup completes, you have multiple ways to connect:

### Option 1: Direct SSH
```bash
ssh developer@my-claude-dev.fly.dev -p 10022
```

### Option 2: VSCode Remote Development
1. Install [Remote-SSH extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh)
2. Add to `~/.ssh/config`:
   ```
   Host my-claude-dev
       HostName my-claude-dev.fly.dev
       Port 10022
       User developer
       IdentityFile ~/.ssh/id_rsa
   ```
3. Connect via Command Palette: `Remote-SSH: Connect to Host`
4. See [detailed VSCode guide](docs/VSCODE.md)

### Option 3: IntelliJ/JetBrains IDEs
1. Install [JetBrains Gateway](https://www.jetbrains.com/remote-development/gateway/)
2. Create SSH connection with your app details
3. See [detailed IntelliJ guide](docs/INTELLIJ.md)

## 🛠️ First-Time Configuration

On your **first connection** to the VM, run the configuration script:

```bash
# After connecting via SSH or IDE terminal
/workspace/scripts/vm-configure.sh
```

This will:
- Install Node.js (latest LTS)
- Install Claude Code and Claude Flow
- Set up Git configuration
- Create workspace directories
- Configure development tools

## 🤖 Start Using Claude

### Authenticate Claude Code
```bash
# Start Claude Code and authenticate
claude

# Choose authentication method:
# 1. Claude Max account (recommended)
# 2. Anthropic API key
```

### Initialize Claude Flow (per project)
```bash
cd /workspace/projects/active/your-project
npx claude-flow@alpha init --force
```

## 💰 Cost Management

Your environment automatically suspends when idle to save costs:

- **Minimal usage**: ~$2-3/month
- **Regular usage**: ~$5-8/month
- **Always-on**: ~$30-50/month

Manage costs with:
```bash
./scripts/vm-suspend.sh     # Manually suspend VM
./scripts/vm-resume.sh      # Resume VM
./scripts/cost-monitor.sh   # Check usage and costs
```

## 📁 Project Structure

Your persistent workspace is organized as:
```
/workspace/
├── projects/
│   ├── active/      # Current projects
│   └── archive/     # Completed projects
├── scripts/         # Utility scripts
├── backups/         # Backup storage
└── .config/         # Configuration files
```

## 🆘 Troubleshooting

### VM won't start?
```bash
flyctl status -a my-claude-dev
flyctl machine list -a my-claude-dev
flyctl machine restart <machine-id> -a my-claude-dev
```

### SSH connection fails?
```bash
# Test connection with verbose output
ssh -vvv developer@my-claude-dev.fly.dev -p 10022

# Check VM logs
flyctl logs -a my-claude-dev
```

### Need more help?
- See [detailed setup guide](SETUP.md) for manual configuration
- Check [VSCode setup](docs/VSCODE.md) for IDE-specific help
- Check [IntelliJ setup](docs/INTELLIJ.md) for JetBrains IDEs
- Visit [Fly.io community](https://community.fly.io) for platform help

## 🎯 Next Steps

1. **Create your first project**:
   ```bash
   cd /workspace/projects/active
   mkdir my-project && cd my-project
   npx claude-flow@alpha init --force
   ```

2. **Set up project context**:
   ```bash
   cp /workspace/templates/CLAUDE.md.template ./CLAUDE.md
   # Edit CLAUDE.md with your project details
   ```

3. **Start coding with AI assistance**:
   ```bash
   claude
   # or
   npx claude-flow@alpha swarm "build a REST API"
   ```

## 📚 Additional Resources

- **[Complete Setup Guide](SETUP.md)** - Detailed manual setup and configuration
- **[VSCode Integration](docs/VSCODE.md)** - Full VSCode remote development guide
- **[IntelliJ Integration](docs/INTELLIJ.md)** - JetBrains IDE setup guide
- **[Cost Optimization](SETUP.md#cost-optimization)** - Tips for reducing costs
- **[Team Collaboration](SETUP.md#team-collaboration)** - Multi-developer setups

---

## Creating SSH Keys

If you don't have SSH keys yet:

```bash
# Option 1: Ed25519 (recommended)
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519

# Option 2: RSA
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

---

**Ready to start?** Run `./scripts/vm-setup.sh` and you'll be coding with Claude in minutes! 🚀