# CLAUDE.md

Project-specific guidance for Claude Code when working with this repository.

## Project Overview

Complete remote AI-assisted development environment running Claude Code and Claude Flow on Fly.io infrastructure.
Provides cost-optimized, secure virtual machines with persistent storage for AI-assisted development without
requiring local installation.

## Development Commands

### VM Management

```bash
./scripts/vm-setup.sh --app-name <name>  # Deploy new VM
./scripts/vm-suspend.sh                  # Suspend to save costs
./scripts/vm-resume.sh                   # Resume VM
./scripts/vm-teardown.sh                 # Remove VM and volumes
flyctl status -a <app-name>             # Check VM status
```

### On-VM Commands

```bash
/workspace/scripts/vm-configure.sh      # Complete environment setup
claude                                   # Authenticate Claude Code
npx claude-flow@alpha init --force      # Initialize Claude Flow in project
new-project <name> [--type <type>]      # Create new project with enhancements
clone-project <url> [options]            # Clone and enhance repository
```

## Key Directories

- `/workspace/` - Persistent volume root (survives VM restarts)
- `/workspace/developer/` - Developer home directory (persistent)
- `/workspace/projects/active/` - Active development projects
- `/workspace/scripts/` - Utility and management scripts
- All user data (npm cache, configs, SSH keys) persists between VM restarts

## Development Workflow

### Daily Tasks

1. Connect via SSH: `ssh developer@<app-name>.fly.dev -p 10022`
2. Work in `/workspace/` (all data persists)
3. VM auto-suspends when idle
4. VM auto-resumes on next connection

### Project Creation

```bash
# New project
new-project my-app --type node

# Clone existing
clone-project https://github.com/user/repo --feature my-feature

# Both automatically:
# - Create CLAUDE.md context
# - Initialize Claude Flow
# - Install dependencies
```

## Testing and Validation

No specific test framework enforced - check each project's README for:

- Test commands (npm test, pytest, go test, etc.)
- Linting requirements
- Build processes

Always run project-specific linting/formatting before commits.

## Agent Configuration

Agents extend Claude's capabilities for specialized tasks. Configuration:

- `/workspace/config/agents-config.yaml` - Agent sources and settings
- `/workspace/.agent-aliases` - Shell aliases for agent commands

Common agent commands:

```bash
agent-manager update       # Update all agents
agent-search "keyword"     # Search available agents
agent-install <name>       # Install specific agent
cf-with-context <agent>    # Run agent with project context
```

## Memory and Context Management

### Project Context

Each project should have its own CLAUDE.md file:

```bash
cp /workspace/templates/CLAUDE.md.example ./CLAUDE.md
# Edit with project-specific commands, architecture, conventions
```

### Claude Flow Memory

- Persistent memory in `.swarm/memory.db`
- Multi-agent coordination and context retention
- Memory survives VM restarts via persistent volume

### Global Preferences

Store user preferences in `/workspace/developer/.claude/CLAUDE.md`:

- Coding style preferences
- Git workflow preferences
- Testing preferences

## Common Operations

### Troubleshooting

```bash
flyctl status -a <app-name>          # Check VM health
flyctl logs -a <app-name>            # View system logs
flyctl machine restart <id>          # Restart if unresponsive
ssh -vvv developer@<app>.fly.dev -p 10022  # Debug SSH
```

### Cost Monitoring

```bash
./scripts/cost-monitor.sh            # Check usage and costs
./scripts/vm-suspend.sh              # Manual suspend
```

See [Cost Management Guide](docs/COST_MANAGEMENT.md) for detailed pricing.

## Important Instructions

- Do what has been asked; nothing more, nothing less
- NEVER create files unless absolutely necessary
- ALWAYS prefer editing existing files to creating new ones
- NEVER proactively create documentation files unless explicitly requested
- Only use emojis if explicitly requested by the user
