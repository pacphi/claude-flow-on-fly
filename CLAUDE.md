# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a complete remote AI-assisted development environment setup running Claude Code and Claude Flow on Fly.io infrastructure. The project provides cost-optimized, secure virtual machines with persistent storage for AI-assisted development without requiring local installation.

## Development Commands

### VM Management
- `./scripts/vm-setup.sh` - Deploy new VM with persistent volume
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

## Architecture Overview

### Infrastructure Components
- **Fly.io VM**: Ubuntu 22.04 container with auto-suspend capabilities
- **Persistent Volume**: Mounted at `/workspace` for all development work
- **SSH Access**: Key-based authentication on port 10022
- **Auto-scaling**: Scale-to-zero when idle, auto-start on connection

### Key Directories
- `/workspace/` - Persistent volume root (survives VM restarts)
- `/workspace/projects/active/` - Active development projects
- `/workspace/projects/archive/` - Archived projects
- `/workspace/scripts/` - Utility and management scripts
- `/workspace/backups/` - Local backup storage
- `/home/developer/` - User home (ephemeral, reset on VM restart)

### Cost Optimization Features
- Auto-suspend VMs when idle (~$2-5/month with minimal usage)
- Scale-to-zero configuration (no compute charges when suspended)
- Persistent volumes maintain data during suspension
- Estimated costs: $2-15/month depending on usage

## Configuration Files

### Core Infrastructure
- `fly.toml` - Fly.io deployment configuration with auto-scaling
- `Dockerfile` - Ubuntu-based development environment
- `scripts/vm-setup.sh` - Automated VM deployment with volume creation

### Templates
- `templates/CLAUDE.md.template` - Project context template for Claude
- `templates/settings.json.template` - Claude Code hooks configuration
- `templates/ssh_config.template` - SSH client configuration

### VM Scripts (Created on first run)
- `vm-configure.sh` - Complete environment setup (Node.js, Claude tools, Git)
- Backup/restore utilities for data management
- Cost monitoring and VM lifecycle management

## Development Workflow

### Initial Setup
1. Run `./scripts/vm-setup.sh --app-name <name> --region <region>`
2. Connect via SSH or IDE remote development
3. Run `/workspace/scripts/vm-configure.sh` for first-time setup
4. Authenticate Claude Code with `claude`
5. Initialize Claude Flow in projects with `npx claude-flow@alpha init --force`

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
- Use templates from `templates/CLAUDE.md.template`
- Include project-specific commands, architecture, and conventions

### Claude Flow Memory
- Persistent memory stored in SQLite at `.swarm/memory.db`
- Multi-agent coordination and context retention
- Memory survives VM restarts via persistent volume

### Global Preferences
- Store user preferences in `/home/developer/.claude/CLAUDE.md`
- Include coding style, Git workflow, and testing preferences

## Common Operations

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