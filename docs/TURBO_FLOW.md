# Turbo-Flow Claude Integration Setup Guide

## Overview

This guide covers integrating [turbo-flow-claude](https://github.com/marcuspat/turbo-flow-claude)-like capabilities within the claude-flow-on-fly environment. The integration brings enterprise-grade AI development features including flexible agent management, multi-tier context systems, tmux workspaces, and verification-first development.

Thanks for the inspiration [Marcus Patman](https://github.com/marcuspat)!

> [!Note]
> As of 2025-08-28 no [commercial](https://devpod.sh/docs/managing-providers/add-provider) or [community](https://devpod.sh/docs/managing-providers/add-provider#community-providers) DevPod provider exists targeting fly.io

## What's New

### 🤖 Flexible Agent Management

- **600+ Agents**: Access to VoltAgent's awesome-claude-code-subagents
- **YAML Configuration**: Easily add/remove agent sources
- **Smart Discovery**: Search agents by name and functionality
- **Automatic Updates**: Keep agents current with upstream sources

### 📚 Multi-Tier Context System

- **Global Context**: CLAUDE.md, CCFOREVER.md
- **User Preferences**: Personal coding style and preferences
- **Project Context**: Project-specific instructions and overrides
- **Hierarchical Loading**: Automatic context composition

### 📺 Tmux Development Environment

- **Multi-Window Setup**: Claude-1, Claude-2, Monitor, htop
- **Session Persistence**: Survives disconnections and VM suspensions
- **Smart Monitoring**: Auto-start monitoring tools
- **Quick Navigation**: Aliases and shortcuts
- **Graceful Shutdown**: Automatic session backup before VM suspension
- **Smart Resume**: Session restoration detection and guided recovery

### 🔍 Quality-First Development

- **Comprehensive Testing**: Code, tests, linting, type safety validation
- **Quality Gates**: Standards enforcement for all operations
- **Systematic Validation**: Structured approach to code quality
- **Best Practices**: Following established development patterns

## Quick Start

### 1. Deploy to Fly.io

```bash
# Clone and customize configuration
git clone https://github.com/pacphi/claude-flow-on-fly
cd claude-flow-on-fly

# Optional: Customize configuration before deployment
nano docker/config/agents-config.yaml    # Configure agent sources
nano docker/config/agent-aliases         # Customize agent aliases
nano docker/lib/agent-discovery.sh       # Add discovery functions
nano docker/config/tmux.conf             # Customize tmux settings
nano docker/lib/tmux-workspace.sh        # Modify workspace launcher
nano docker/config/tmux-aliases          # Customize tmux shortcuts

# Deploy with your configuration
./scripts/vm-setup.sh --app-name my-claude-env
```

### 2. Initial Configuration

```bash
# SSH into your VM
ssh developer@my-claude-env.fly.dev -p 10022

# Run the enhanced configuration
/workspace/scripts/vm-configure.sh

# Validate the installation
/workspace/scripts/validate-setup.sh
```

### 3. Start Development

```bash
# Authenticate Claude Code
claude

# Start the tmux workspace
tmux-workspace

# Install agents
agent-install

# Begin AI-assisted development
cf-swarm "Build a modern web application with authentication"
```

## Feature Guide

### Agent Management

#### Installing Agents

```bash
# Install all configured agents
agent-install

# Install specific source
agent-install --source awesome-claude-code-subagents

# List installed agents
agent-list

# Update agents
agent-update
```

#### Finding Agents

The agent discovery system provides powerful search capabilities:

```bash
# Get help on all agent commands
agent-help

# Basic search
agent-find "testing"         # Search by name
agent-search "react"          # Search by content
agent-by-category            # Browse by category
agent-by-tag "security"      # Find by tag
agent-with-keyword "api"     # Find by filename keyword

# Information and statistics
agent-count                  # Total agent count
agent-stats                  # Comprehensive statistics
agent-list-all               # List all with descriptions
agent-info <file>            # Show agent metadata

# Advanced features
agent-index                  # Create search index for speed
agent-search-fast "term"     # Use indexed search (faster)
agent-duplicates             # Find duplicate agents
agent-validate-all           # Validate all agents

# Random discovery
agent-sample                 # Show 5 random agents
agent-sample 10              # Show 10 random agents
```

#### Adding Custom Agent Sources

You can customize agent sources in two ways:

**Before deployment** (recommended):

```bash
# Edit templates before VM setup
nano docker/config/agents-config.yaml    # Configure agent sources
nano docker/config/agent-aliases         # Customize agent aliases
nano docker/lib/agent-discovery.sh       # Add discovery functions
nano docker/config/tmux.conf             # Customize tmux settings
nano docker/lib/tmux-workspace.sh        # Modify workspace launcher
```

**After deployment**:

```bash
# Edit deployed configurations
nano /workspace/config/agents-config.yaml          # Agent sources
nano /workspace/.agent-aliases                     # Agent aliases
nano /workspace/scripts/lib/agent-discovery.sh     # Discovery functions
nano /workspace/config/tmux.conf                   # Tmux configuration
nano /workspace/scripts/tmux-workspace.sh          # Workspace launcher
nano /workspace/.tmux-aliases                      # Tmux aliases

# Then reload/reinstall (these are auto-sourced in new sessions)
source /workspace/.agent-aliases                   # Reload agent aliases
source /workspace/scripts/lib/agent-discovery.sh   # Reload discovery functions
source /workspace/.tmux-aliases                    # Reload tmux aliases
tmux source-file ~/.tmux.conf                      # Reload tmux config
agent-install                                      # Reinstall agents if config changed
```

Example custom source configuration:

```yaml
sources:
  - name: my-custom-agents
    enabled: true
    type: github
    repository: my-org/my-agents
    branch: main
    paths:
      source: agents
      target: ${settings.base_dir}
    filters:
      include_patterns:
        - "*.md"
```

### Context Management

#### Viewing Context

```bash
# View all context files
load-context

# View specific context
load-global       # Global context only
load-user         # User preferences only
load-project      # Project context only

# Validate context system
validate-context
```

#### Context Hierarchy

1. **Global Context** (`/workspace/context/global/`)
   - `CLAUDE.md`: Core configuration and rules
   - `CCFOREVER.md`: Quality assurance protocols

2. **User Preferences** (`~/.claude/CLAUDE.md`)
   - Personal coding style
   - Preferred frameworks and tools

3. **Project Context** (`./CLAUDE.md`)
   - Project-specific instructions
   - Architecture decisions
   - Development workflow

4. **Session Overrides** (`$CLAUDE_SESSION_CONTEXT`)
   - Runtime modifications
   - Temporary session changes

#### Using Context with Claude Flow

```bash
# Claude Flow with automatic context loading
cf-swarm "Implement user authentication"
cf-hive "Optimize database performance"

# Verify context loading
context-hierarchy
```

### Tmux Workspace

#### Starting the Workspace

```bash
# Start/attach to workspace
tmux-workspace

# Force create new session
tmux-workspace --new

# Check session status
tmux-status
```

#### Window Layout

- **Window 0 (Claude-1)**: Primary Claude Code session
- **Window 1 (Claude-2)**: Secondary Claude session
- **Window 2 (Monitor)**: Claude usage monitoring
- **Window 3 (htop)**: System resource monitoring

#### Navigation Shortcuts

```bash
# Quick window switching
t0    # Switch to Claude-1
t1    # Switch to Claude-2
t2    # Switch to Monitor
t3    # Switch to htop

# Session management
tmux-attach           # Attach to existing session
tmux-list            # List all sessions
tmux-cleanup         # Clean up old sessions
tmux-resume-workspace # Smart resume (existing or new)
```

#### Session Persistence & Recovery

The enhanced tmux system provides robust session management:

**Automatic Backup During VM Suspension:**

```bash
# When you suspend the VM, sessions are automatically:
# 1. Backed up to /workspace/backups/shutdown-YYYYMMDD-HHMMSS/
# 2. All panes receive Ctrl+S for editor saves
# 3. Users get notification messages
# 4. Session layouts are preserved

./scripts/vm-suspend.sh    # Triggers automatic session backup
```

**Smart Resume After VM Restart:**

```bash
# When VM resumes, the system detects:
# - Active sessions (automatically restored by tmux)
# - Available backup files for manual restoration
# - Session save files from helper functions

./scripts/vm-resume.sh     # Shows detailed restoration status
```

**Manual Session Management:**

```bash
# Session backup and restore
tmux-backup-all       # Manually backup all current sessions
tmux-find-backups     # List available backups
tmux-restore-last     # Restore from most recent shutdown backup
tmux-save             # Save current session layout
tmux-restore          # Restore saved session layout

# Development workflows
tmux-dev-quick        # Quick 3-pane development layout
tmux-resume-workspace # Smart workspace resumption
```

### Quality Assurance System

#### Running Quality Checks

```bash
# Basic setup validation
/workspace/scripts/validate-setup.sh

# Context system validation
validate-context

# System status check
/workspace/scripts/lib/system-status.sh
```

#### Quality Standards

The system enforces quality through:

- **Build Validation**: Code compiles successfully
- **Test Coverage**: Comprehensive test suites
- **Code Standards**: Linting and formatting compliance
- **Type Safety**: Static analysis for typed languages

#### Quality Process

When implementing features:

1. Run build and tests before committing
2. Apply linting and formatting standards
3. Validate type safety requirements
4. Review and refactor as needed

## Project Development Workflow

### 1. Create New Project

```bash
# Create project with context
new-project my-app node
cd my-app

# Add project-specific context
new-project-context
nano CLAUDE.md  # Customize for your project
```

### 2. Development Session

```bash
# Start tmux workspace
tmux-workspace

# Load mandatory agents and begin development
cf swarm "
Create a REST API for user management with:
- Authentication and authorization
- User CRUD operations
- Data validation
- Error handling
- Unit and integration tests

Use doc-planner and microtask-breakdown agents to structure the work.
"
```

### 3. Quality Validation Loop

```bash
# Run quality checks throughout development
npm test                    # Run test suite
npm run lint               # Check code standards
npm run typecheck          # Validate types
npm run build              # Ensure compilation

# Use basic validation script
/workspace/scripts/validate-setup.sh
```

### 4. Visual Testing (Frontend)

```bash
# Playwright is pre-configured
npm run playwright
npx playwright test --ui
```

## Configuration Reference

### Key Configuration Files

| File | Purpose | Location |
|------|---------|----------|
| `agents-config.yaml` | Agent sources | `/workspace/config/` |
| `tmux.conf` | Tmux configuration | `/workspace/config/` |
| `CLAUDE.md` | Global context | `/workspace/context/global/` |
| `CCFOREVER.md` | Quality assurance | `/workspace/context/global/` |

### Environment Variables

```bash
# Context system
export CLAUDE_SESSION_CONTEXT="Additional session instructions"

# Tmux workspace
export TMUX_SESSION_NAME=claude-workspace
```

### Alias Reference

#### Agent Management

```bash
agent-install              # Install all agents
agent-list                 # List available agents
agent-update               # Update agents
agent-validate             # Validate configuration
agent-count                # Count total agents
agent-find <term>          # Search for agents
agent-sample               # Sample random agents
```

#### Context Management

```bash
load-context               # View all context
validate-context           # Validate context system
context-hierarchy          # Show loading hierarchy
cf-l <command>             # Claude Flow with context
new-project-context        # Create project context
```

#### Tmux Management

```bash
tmux-workspace             # Start workspace
tmux-status                # Show session status
tmux-cleanup               # Clean old sessions
t0, t1, t2, t3            # Quick window switching
```

#### Development

```bash
claude                     # Start Claude Code
dsp                       # Claude with skip permissions
/workspace/scripts/validate-setup.sh # Validate installation
monitor-claude            # Start usage monitoring
```

## Troubleshooting

### Common Issues

#### 1. Agent Installation Fails

```bash
# Check network connectivity
curl -I https://api.github.com

# Validate configuration
agent-manager validate

# Re-run installation
agent-install --source awesome-claude-code-subagents
```

#### 2. Context Not Loading

```bash
# Check file permissions
find /workspace/context -type f -exec ls -la {} \;

# Validate context files
validate-context

# Test context loading
source /workspace/scripts/lib/context-loader.sh
load_all_context
```

#### 3. Tmux Session Issues

```bash
# Check tmux installation
tmux -V

# Validate configuration
tmux -f /workspace/config/tmux.conf list-keys

# Force new session
tmux-workspace --new
```

#### 4. Quality Check Issues

```bash
# Check system logs
tail -20 /workspace/logs/system.log

# Show current status
/workspace/scripts/lib/system-status.sh

# Run setup validation
/workspace/scripts/validate-setup.sh
```

### Getting Help

1. **Run Setup Validation**

   ```bash
   /workspace/scripts/validate-setup.sh
   ```

2. **Check System Status**

   ```bash
   /workspace/scripts/lib/system-status.sh
   ```

3. **Review Logs**

   ```bash
   ls -la /workspace/logs/
   tail -50 /workspace/logs/system.log
   ```

4. **Reset Configuration**

   ```bash
   /workspace/scripts/vm-configure.sh --interactive
   ```

## Advanced Usage

### Custom Agent Development

Create your own agents following the [Claude Code sub-agent format](https://docs.anthropic.com/en/docs/claude-code/sub-agents#file-format):

```markdown
name: My Custom Agent
description: Specialized agent for my specific needs

## Instructions
You are a specialized agent that helps with...

## Capabilities
- Specific capability 1
- Specific capability 2

## Usage Examples
Use this agent when you need to...
```

### Context Customization

Customize global context for your organization:

```bash
# Edit global context
nano /workspace/context/global/CLAUDE.md

# Add organization-specific rules
# Update development standards
# Include security requirements
```


## Performance Optimization

### Agent Loading

- Use `agent-find` instead of loading all agents
- Configure only needed sources in agents-config.yaml
- Regular cleanup with agent update cycles

### Context Management

- Keep project context files small and focused
- Use session overrides for temporary changes
- Validate context regularly to avoid bloat

### Tmux Performance

- Adjust scrollback buffer if memory constrained
- Use session persistence to avoid repeated startup
- Monitor resource usage in htop window

## Migration from Previous Setups

### From Basic Claude-Flow-on-Fly

```bash
# Your existing data is preserved
# Run the integration setup
/workspace/scripts/vm-configure.sh

# Validate migration
/workspace/scripts/validate-setup.sh
```

### From Local Turbo-Flow-Claude

```bash
# Copy your custom agents
cp /path/to/your/agents/*.md /workspace/agents/

# Copy your context customizations
cp /path/to/your/CLAUDE.md /workspace/context/global/

# Update agents config to include your sources
nano /workspace/config/agents-config.yaml
```

## Support and Resources

- **Documentation**: `/workspace/docs/`
- **Examples**: `/workspace/projects/templates/`
- **Logs**: `/workspace/logs/`
- **Configuration**: `/workspace/config/`
- **Validation**: `/workspace/scripts/validate-setup.sh`

For issues and contributions, see the project repository.

---

**Ready to begin AI-assisted development with enterprise-grade capabilities!** 🚀
