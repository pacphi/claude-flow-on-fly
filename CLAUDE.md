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

# CI/Testing deployment (disables SSH daemon, health checks)
CI_MODE=true ./scripts/vm-setup.sh --app-name <test-name>
flyctl deploy --strategy immediate --wait-timeout 60s  # Skip health checks
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
   - Alternative: `flyctl ssh console -a <app-name>` (uses Fly.io's hallpass service)
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

### AI Research Tools

```bash
# Goalie - AI-powered research assistant with GOAP planning
goalie "research question"           # Perform research with Perplexity API
goalie --help                        # View available options

# Requires PERPLEXITY_API_KEY environment variable
# Set via: flyctl secrets set PERPLEXITY_API_KEY=pplx-... -a <app-name>
# Get API key from: https://www.perplexity.ai/settings/api
```

### AI CLI Tools

Additional AI coding assistants available via the `87-ai-tools.sh` extension:

#### Autonomous Coding Agents

```bash
# Codex CLI - Multi-mode AI assistant
codex suggest "optimize this function"
codex edit file.js
codex run "create REST API"

# Claude Squad - Terminal-based AI assistant
claude-squad "implement authentication"

# Plandex - Multi-step development tasks
plandex init                         # Initialize in project
plandex plan "add user auth"         # Plan task
plandex execute                      # Execute plan

# Hector - Declarative AI agent platform
hector serve --config agent.yaml     # Start agent server
hector chat assistant                # Interactive chat
hector call assistant "task"         # Execute single task
hector list                          # List available agents
```

#### Platform CLIs

```bash
# Gemini CLI (requires GOOGLE_GEMINI_API_KEY)
gemini chat "explain this code"
gemini generate "write unit tests"

# GitHub Copilot CLI (requires gh and GitHub account)
gh copilot suggest "git command to undo"
gh copilot explain "docker-compose up"

# AWS Q Developer (requires AWS CLI from 85-cloud-tools.sh)
aws q chat
aws q explain "lambda function"
```

#### Local AI (No API Keys)

```bash
# Ollama - Run LLMs locally
nohup ollama serve > ~/ollama.log 2>&1 &   # Start service
ollama pull llama3.2                        # Pull model
ollama run llama3.2                         # Interactive chat
ollama list                                 # List installed models

# Fabric - AI framework with patterns
fabric --setup                              # First-time setup
echo "code" | fabric --pattern explain     # Use pattern
fabric --list                               # List patterns
```

#### API Keys Setup

```bash
# Via Fly.io secrets (recommended)
flyctl secrets set GOOGLE_GEMINI_API_KEY=... -a <app-name>
flyctl secrets set GROK_API_KEY=... -a <app-name>

# Or in shell (temporary)
export GOOGLE_GEMINI_API_KEY=your_key
export GROK_API_KEY=your_key
```

**Get API keys:**

- Gemini: <https://makersuite.google.com/app/apikey>
- Grok: xAI account required

**Enable the extension:**

```bash
extension-manager activate ai-tools
/workspace/scripts/vm-configure.sh --extension ai-tools
```

See `/workspace/ai-tools/README.md` for complete documentation.

### AI Model Management with agent-flow

Agent-flow provides cost-optimized multi-model AI routing for development tasks:

#### Available Providers

- **Anthropic Claude** (default, requires ANTHROPIC_API_KEY)
- **OpenRouter** (100+ models, requires OPENROUTER_API_KEY)
- **Gemini** (free tier, requires GOOGLE_GEMINI_API_KEY)

#### Common Commands

```bash
# Agent-specific tasks
af-coder "Create REST API with OAuth2"       # Use coder agent
af-reviewer "Review code for vulnerabilities" # Use reviewer agent
af-researcher "Research best practices"      # Use researcher agent

# Provider selection
af-openrouter "Build feature"                # OpenRouter provider
af-gemini "Analyze code"                     # Free Gemini tier
af-claude "Write tests"                      # Anthropic Claude

# Optimization modes
af-cost "Simple task"                        # Cost-optimized model
af-quality "Complex refactoring"             # Quality-optimized model
af-speed "Quick analysis"                    # Speed-optimized model

# Utility functions
af-task coder "Create API endpoint"          # Balanced optimization
af-provider openrouter "Generate docs"       # Provider wrapper
```

#### Setting API Keys

```bash
# On host machine (before deployment)
flyctl secrets set OPENROUTER_API_KEY=sk-or-... -a <app-name>
flyctl secrets set GOOGLE_GEMINI_API_KEY=... -a <app-name>
```

**Get API keys:**

- OpenRouter: <https://openrouter.ai/keys>
- Gemini: <https://makersuite.google.com/app/apikey>

**Benefits:**

- **Cost savings**: 85-99% reduction using OpenRouter's low-cost models
- **Flexibility**: Switch between 100+ models based on task complexity
- **Free tier**: Use Gemini for development/testing
- **Seamless integration**: Works alongside existing Claude Flow setup

See [Cost Management Guide](docs/COST_MANAGEMENT.md) for detailed pricing.

## SSH Architecture Notes

The environment provides dual SSH access:

- **Production SSH**: External port 10022 → Internal port 2222 (custom daemon)
- **Hallpass SSH**: `flyctl ssh console` via Fly.io's built-in service (port 22)

In CI mode (`CI_MODE=true`), the custom SSH daemon is disabled to prevent port conflicts with Fly.io's hallpass service,
ensuring reliable automated deployments.

### CI Mode Limitations and Troubleshooting

**SSH Command Execution in CI Mode:**

- Complex multi-line shell commands may fail after machine restarts
- Always use explicit shell invocation: `/bin/bash -c 'command'`
- Avoid nested quotes and complex variable substitution
- Use retry logic for commands executed immediately after restart

**Volume Persistence Verification:**

- Volumes persist correctly, but SSH environment may need time to initialize after restart
- Add machine readiness checks before testing persistence
- Use simple commands to verify mount points and permissions

**Common Issues:**

- `exec: "if": executable file not found in $PATH` - Use explicit bash invocation
- SSH connection timeouts after restart - Add retry logic with delays
- Environment variables not available - Check shell environment setup

**Best Practices for CI Testing:**

- Always verify machine status before running tests
- Use explicit error handling and debugging output
- Split complex operations into simple, atomic commands
- Add volume mount verification before persistence tests

## Important Instructions

- Do what has been asked; nothing more, nothing less
- NEVER create files unless absolutely necessary
- ALWAYS prefer editing existing files to creating new ones
- NEVER proactively create documentation files unless explicitly requested
- Only use emojis if explicitly requested by the user
