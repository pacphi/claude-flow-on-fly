# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a complete remote AI-assisted development environment setup running Claude Code and Claude Flow on Fly.io infrastructure. The project provides cost-optimized, secure virtual machines with persistent storage for AI-assisted development without requiring local installation.

## Development Commands

### VM Management
- `./scripts/vm-setup.sh` - Deploy new VM with persistent volume
  - Options: `--cpu-kind shared|performance --cpu-count N --memory N`
- `./scripts/vm-teardown.sh` - Safely remove VM, volumes, and resources
- `./scripts/vm-suspend.sh` - Suspend VM to save costs
- `./scripts/vm-resume.sh` - Resume suspended VM
- `flyctl status` - Check VM status and health
- `flyctl logs` - View VM logs for debugging

### Data Management
- `./scripts/volume-backup.sh` - Create backup of workspace data
- `./scripts/volume-restore.sh` - Restore from backup
- `./scripts/cost-monitor.sh` - Monitor usage and costs

### VM Connection
- `ssh developer@<app-name>.fly.dev -p 10022` - Direct SSH connection
- Configure VSCode Remote-SSH or IntelliJ Gateway for IDE integration

### On-VM Configuration (First Time)
- `/workspace/scripts/vm-configure.sh` - Complete environment setup
- `claude` - Authenticate Claude Code
- `npx claude-flow@alpha init --force` - Initialize Claude Flow in project

### Project Management
- `new-project <name> [--type <type>]` - Create new project with Claude enhancements
- `clone-project <url> [options]` - Clone or fork existing repository with enhancements
  - `--fork` - Fork the repository using GitHub CLI before cloning
  - `--branch <name>` - Clone specific branch
  - `--feature <name>` - Create feature branch after clone/fork
  - `--git-name/--git-email` - Configure Git for this project
  - `--no-enhance` - Skip Claude enhancements (just clone/fork)

## Architecture Overview

### Infrastructure Components
- **Fly.io VM**: Ubuntu 22.04 container with auto-suspend capabilities
- **Persistent Volume**: Mounted at `/workspace` for all development work
- **SSH Access**: Key-based authentication on port 10022
- **Auto-scaling**: Scale-to-zero when idle, auto-start on connection

### Key Directories
- `/workspace/` - Persistent volume root (survives VM restarts)
- `/workspace/developer/` - Developer home directory (persistent, 30GB+)
- `/workspace/projects/active/` - Active development projects
- `/workspace/projects/archive/` - Archived projects
- `/workspace/scripts/` - Utility and management scripts
- `/workspace/backups/` - Local backup storage

### Storage Architecture
- **Persistent Volume**: 30GB mounted at `/workspace` with auto-extension up to 100GB
- **Developer Home**: Located at `/workspace/developer` (fully persistent)
- **Ephemeral Storage**: System files only (~8GB, automatically managed)
- **Swap Space**: 2GB for memory pressure relief during builds
- **Auto-extension**: Volume grows by 5GB when 80% full
- **Snapshots**: Daily backups retained for 7 days

All user data (npm cache, pip cache, installed tools, SSH keys, configs) persists between VM restarts.

### Cost Optimization Features
- Auto-suspend VMs when idle (~$6.78/month with default configuration at 10% uptime)
- Scale-to-zero configuration (no compute charges when suspended)
- Persistent volumes maintain data during suspension
- Estimated costs: $6.78-27.25/month depending on usage and configuration

## File Organization

### Build-time vs Runtime Structure

This project has two distinct file structures:

1. **Build-time (Repository)**: Files in this repository used to build and deploy the VM
   - `docker/` - Source files for the Docker image
   - `scripts/` - Local management scripts run from your machine
   - `templates/` - User-editable configuration templates
   - Configuration and library files that get copied to the VM

2. **Runtime (VM)**: File locations after deployment to the VM
   - `/workspace/` - Persistent volume mount point
   - `/workspace/scripts/` - Management scripts available on the VM
   - `/workspace/scripts/lib/` - Shared libraries used by scripts
   - `/workspace/developer/` - User home directory (persistent)

### File Mapping

| Repository Location | Runtime Location (on VM) | Purpose |
|-------------------|-------------------------|----------|
| `docker/scripts/vm-configure.sh` | `/workspace/scripts/vm-configure.sh` | Main configuration script |
| `docker/lib/*.sh` | `/workspace/scripts/lib/*.sh` | Shared utility libraries |
| `docker/config/*` | Copied to various locations | Configuration files |
| `docker/lib/extensions.d/*.sh` | `/workspace/scripts/extensions.d/*.sh` | Extension scripts |
| `templates/*.example` | User reference only | Example configurations |

## Configuration Files

### Core Infrastructure
- `fly.toml` - Fly.io deployment configuration with auto-scaling
- `Dockerfile` - Ubuntu-based development environment
- `scripts/vm-setup.sh` - Automated VM deployment with volume creation

### Templates
- `templates/CLAUDE.md.example` - Project context template for Claude
- `templates/settings.json.example` - Claude Code hooks configuration
- `templates/ssh_config.example` - SSH client configuration
- `docker/config/agents-config.yaml` - Agent manager configuration template
- `docker/config/agent-aliases` - Agent management shell aliases
- `docker/lib/agent-discovery.sh` - Agent discovery utility functions
- `docker/config/tmux.conf` - Tmux configuration with keybindings and styling
- `docker/lib/tmux-workspace.sh` - Main tmux workspace launcher script
- `docker/lib/tmux-helpers.sh` - Tmux session management utility functions
- `docker/config/tmux-aliases` - Tmux operation shell aliases
- `docker/lib/tmux-auto-start.sh` - Optional SSH auto-start functionality

### VM Scripts (Created on first run)
- `vm-configure.sh` - Complete environment setup (Node.js, Claude tools, Git)
- `backup.sh` - Backup critical workspace data
- `restore.sh` - Restore from backup files
- `new-project.sh` - Create new projects with Git integration
- `system-status.sh` - Show system and development environment status

### Library Structure
- `/workspace/scripts/lib/` - Shared utility libraries (runtime location)
  - `common.sh` - Core functions used by all scripts (colors, print functions, utilities)
  - `workspace.sh` - Workspace management utilities (delegates to script files)
  - `tools.sh` - Tool installation functions (Node.js, Claude Code, language tools)
  - `git.sh` - Git configuration helpers (setup, aliases, hooks)
  - `gh.sh` - GitHub CLI utilities and integrations
  - `backup.sh` - Backup utilities for workspace data
  - `restore.sh` - Restore utilities for workspace backups
  - `new-project.sh` - Project creation with Git integration
  - `system-status.sh` - System monitoring and status display
  - `agent-discovery.sh` - Agent discovery and search functions
  - `context-loader.sh` - Context file loading and management
  - `cf-with-context.sh` - Claude Flow with context integration
  - `tmux-helpers.sh` - Tmux session management utilities
  - `tmux-workspace.sh` - Main tmux workspace launcher
  - `tmux-auto-start.sh` - Optional SSH auto-start functionality
  - `validate-setup.sh` - Validation script for environment setup
- `/workspace/scripts/extensions.d/` - Custom tool installations
  - Add numbered scripts here for automatic execution during configuration
  - Scripts run in alphabetical order: pre-*, *, post-*
  - Examples: `10-rust.sh.example`, `20-golang.sh.example`, `30-docker.sh.example`

## Agent Configuration

### Prerequisites

**IMPORTANT**: Agent installation requires GitHub authentication. Set your GitHub token before deployment:
```bash
flyctl secrets set GITHUB_TOKEN=ghp_... -a <app-name>
```
Without this, agent-manager cannot clone repositories from GitHub.

### Customizing Agent Sources

Before deploying, you can customize which agent sources will be installed by editing:
- `docker/config/agents-config.yaml` - Configure agent sources, update strategies, and mandatory agents

Key customization options:
- **Enable/disable sources**: Set `enabled: true/false` for each source
- **Add custom repositories**: Configure your own GitHub repositories or local paths
- **Set mandatory agents**: Define which agents must always be installed
- **Configure update strategies**: Control how agents are updated (merge/replace)
- **Filter patterns**: Include/exclude specific files or patterns
- **Customize aliases**: Modify `docker/config/agent-aliases` to add your own shortcuts
- **Extend discovery**: Enhance `docker/lib/agent-discovery.sh` with custom search functions
- **Customize tmux**: Modify tmux templates for personalized development environment

The configuration files are copied to `/workspace/config/` and `/workspace/.agent-aliases` on first run and preserved across reconfigurations.

## Development Workflow

### Initial Setup
1. Set GitHub token for agent installation: `flyctl secrets set GITHUB_TOKEN=ghp_... -a <app-name>`
2. Run `./scripts/vm-setup.sh --app-name <name> --region <region>`
3. Connect via SSH or IDE remote development
4. Run `/workspace/scripts/vm-configure.sh` for first-time setup
5. Authenticate Claude Code with `claude`
6. Initialize Claude Flow in projects with `npx claude-flow@alpha init --force`

### Daily Development
1. Connect via IDE (VSCode Remote-SSH or IntelliJ Gateway)
2. All work should be in `/workspace/` (persistent)
3. VM auto-suspends when idle to save costs
4. VM auto-resumes on next connection

### Team Collaboration Options
- **Shared VM**: Multiple developers on one VM with separate SSH keys
- **Individual VMs**: Separate VMs with shared data via volume snapshots
- **Claude Flow Swarm**: Multi-agent coordination for team development

## Security Features

### SSH Security
- Key-based authentication only (passwords disabled)
- Non-standard SSH port (10022) to reduce attack surface
- Root login disabled
- Network isolation via Fly.io private networking

### API Key Management
- Secrets stored via `flyctl secrets set`
- Environment variables for secure API key access
- No API keys in code or configuration files

### Data Protection
- Automatic daily volume snapshots (retained 5 days)
- Manual backup scripts for critical data
- Encrypted volume support available

## IDE Integration

### VSCode Setup
- Install Remote-SSH extension
- Configure SSH host in `~/.ssh/config`
- Connect to `<app-name>.fly.dev:10022`

### IntelliJ Setup
- Use JetBrains Gateway
- Configure SSH connection with key authentication
- Select project directory in `/workspace/`

## Memory and Context Management

### Project Context
- Each project should have its own `CLAUDE.md` file
- Use templates from `templates/CLAUDE.md.example`
- Include project-specific commands, architecture, and conventions

### Claude Flow Memory
- Persistent memory stored in SQLite at `.swarm/memory.db`
- Multi-agent coordination and context retention
- Memory survives VM restarts via persistent volume

### Global Preferences
- Store user preferences in `/workspace/developer/.claude/CLAUDE.md`
- Include coding style, Git workflow, and testing preferences

## Common Operations

### Project Creation
- Use `new-project.sh` to create new projects with proper Git setup:
  ```bash
  new-project.sh my-app --type node
  new-project.sh my-app --git-name "John Doe" --git-email "john@example.com"
  ```
- Use `clone-project.sh` to clone and enhance existing repositories:
  ```bash
  clone-project https://github.com/user/repo
  clone-project https://github.com/original/repo --fork --feature my-feature
  clone-project https://github.com/company/app --git-name "John" --git-email "john@company.com"
  ```
- New projects support types: node, python, go, rust, web
- Clone projects automatically detect dependencies and install them
- Both create CLAUDE.md context and initialize Claude Flow
- Fork mode sets up upstream remotes and helpful Git aliases

### Testing and Validation
- No specific test framework - varies by project
- Check README.md or project documentation for test commands
- Always run linting/formatting before commits

### Deployment
- Projects deploy independently (not the VM infrastructure)
- VM serves as development environment only
- Use project-specific deployment processes

### Troubleshooting
- `flyctl status` - Check VM health
- `flyctl logs` - View system logs
- `flyctl machine restart <id>` - Restart VM if unresponsive
- SSH with `-vvv` for connection debugging

#### Storage Issues
- `df -h` - Check disk usage (both ephemeral and persistent)
- Home directory is at `/workspace/developer` (persistent)
- All caches and tools automatically use persistent storage
- Volume auto-extends when 80% full (check with `flyctl volumes list`)
- 2GB swap available for memory-intensive builds

## Cost Management

### Monitoring
- Run `./scripts/cost-monitor.sh` to check usage
- Estimated costs displayed with VM/volume breakdown
- Track uptime and suspend patterns

### Optimization
- VMs automatically suspend after idle timeout
- Manual suspend with `./scripts/vm-suspend.sh`
- Resume with `./scripts/vm-resume.sh`
- Scale VM resources up/down as needed

This remote development environment eliminates local setup complexity while providing powerful AI-assisted development capabilities with cost-effective scaling.