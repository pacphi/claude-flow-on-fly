# Agent System Guide

Agents extend Claude's capabilities for specialized tasks. The environment includes comprehensive agent management
through shell aliases.

## Quick Start

```bash
# See all available agent commands
agent-help

# Install agents
agent-install

# Search for agents
agent-find "test"
agent-search "python"
```

## Available Commands

All agent commands are defined in `/workspace/.agent-aliases`. Key commands include:

### Core Management

- `agent-install` - Install agents from configured sources
- `agent-update` - Update to latest versions
- `agent-list` - List installed agents
- `agent-validate` - Validate configuration

### Search & Discovery

- `agent-find <term>` - Search by name
- `agent-search <term>` - Search by content
- `agent-by-category` - Browse by category
- `agent-by-tag <tag>` - Find by tag
- `agent-with-keyword <keyword>` - Find by filename keyword
- `agent-sample [count]` - See random examples
- `agent-stats` - Comprehensive statistics
- `agent-info <file>` - Show agent metadata
- `agent-index` - Create search index for speed
- `agent-search-fast <term>` - Use indexed search (faster)
- `agent-duplicates` - Find duplicate agents

### Using with Claude Flow

Context-aware agent usage is defined in `/workspace/.context-aliases`:

```bash
# Run with project context
cf-l <agent-name> "task"

# Example
cf-l code-reviewer "review the API module"
```

## Configuration

Agent sources and settings: `/workspace/config/agents-config.yaml`

**Note**: GitHub token required for agent installation:

```bash
flyctl secrets set GITHUB_TOKEN=ghp_... -a <app-name>
```

### Custom Agent Sources

You can customize agent sources in two ways:

**Before deployment** (recommended):

```bash
# Edit templates before VM setup
nano docker/config/agents-config.yaml    # Configure agent sources
nano docker/config/agent-aliases         # Customize agent aliases
nano docker/lib/agent-discovery.sh       # Add discovery functions
```

**After deployment**:

```bash
# Edit deployed configurations
nano /workspace/config/agents-config.yaml          # Agent sources
nano /workspace/.agent-aliases                     # Agent aliases
nano /workspace/scripts/lib/agent-discovery.sh     # Discovery functions

# Then reload
source /workspace/.agent-aliases                   # Reload agent aliases
source /workspace/scripts/lib/agent-discovery.sh   # Reload discovery functions
agent-install                                      # Reinstall agents if config changed
```

**Example custom source configuration:**

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

## Finding Commands

View all available commands and their usage:

```bash
# Show all agent commands with descriptions
agent-help

# Check alias definitions directly
cat /workspace/.agent-aliases
cat /workspace/.context-aliases
```

## Common Workflows

```bash
# Initial setup
agent-install
agent-count

# Find specific agent
agent-find "test"
agent-info <agent-file>

# Update periodically
agent-update
```

For complete command reference, run `agent-help` or examine the alias files directly.

## Custom Agent Development

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

Place custom agents in your configured source directory and run `agent-install` to make them available.
