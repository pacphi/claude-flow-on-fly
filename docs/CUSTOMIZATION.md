# Customization

## Extension System

The environment supports extensive customization through a modular extension system that allows you to add tools,
configure environments, and automate setup tasks.

## Adding Custom Tools

### Extension Script Structure

Extensions are shell scripts placed in `/workspace/scripts/extensions.d/` that run during environment configuration:

```bash
#!/bin/bash
# /workspace/scripts/extensions.d/50-mycustomtool.sh

# Load common utilities
source /workspace/scripts/lib/common.sh

print_status "Installing my custom tool..."

# Your installation commands here
curl -sSL https://example.com/install.sh | bash
export PATH="$PATH:/usr/local/bin/mycustomtool"

# Persist PATH changes
echo 'export PATH="$PATH:/usr/local/bin/mycustomtool"' >> /workspace/developer/.bashrc

print_success "Custom tool installed"
```

### Extension Execution Order

Extensions run in alphabetical order with phase-based prefixes:

- **pre-*** - Setup tasks that must run first
- **00-init** - Core environment initialization (protected, required)
- **05-70*** - Language-specific tools
- **80-90*** - Infrastructure and development tools
- **post-*** - Cleanup and finalization tasks

### Creating Extensions

**Create a new extension:**

```bash
# Create script file
cat > /workspace/scripts/extensions.d/50-mycustomtool.sh << 'EOF'
#!/bin/bash
source /workspace/scripts/lib/common.sh

print_status "Installing custom tool..."
# Installation commands
print_success "Custom tool ready"
EOF

# Make executable
chmod +x /workspace/scripts/extensions.d/50-mycustomtool.sh

# Run just your new extension (if it's activated)
/workspace/scripts/vm-configure.sh --extension mycustomtool

# Or run all extensions
/workspace/scripts/vm-configure.sh --extensions-only
```

### Extension Manager Utility

The `extension-manager.sh` utility in `/workspace/docker/lib/` provides comprehensive management for activating
and deactivating extensions:

**List all available extensions:**

```bash
# Show all extensions and their activation status
/workspace/docker/lib/extension-manager.sh list

# Example output:
# Available extensions in /workspace/scripts/extensions.d:
#
#   ✓ python (05-python.sh) - activated
#   ○ rust (10-rust.sh.example) - not activated
#   ○ golang (20-golang.sh.example) - not activated
#   ✓ docker (30-docker.sh) - activated
```

**Activate a single extension:**

```bash
# Activate Rust toolchain
/workspace/docker/lib/extension-manager.sh activate rust

# Activate Python development tools
/workspace/docker/lib/extension-manager.sh activate python

# Activate Docker utilities
/workspace/docker/lib/extension-manager.sh activate docker
```

**Deactivate a single extension:**

```bash
# Deactivate with confirmation prompt
/workspace/docker/lib/extension-manager.sh deactivate golang

# Deactivate without confirmation
/workspace/docker/lib/extension-manager.sh deactivate golang --yes

# Deactivate and create backup (automatic for modified extensions)
/workspace/docker/lib/extension-manager.sh deactivate python --backup --yes
```

**Activate all extensions:**

```bash
# Activate all available extensions at once
/workspace/docker/lib/extension-manager.sh activate-all

# Summary output shows:
#   Activated: 6
#   Skipped (already active): 2
#   Failed: 0
```

**Deactivate all non-protected extensions:**

```bash
# Deactivate all with confirmation
/workspace/docker/lib/extension-manager.sh deactivate-all

# Deactivate all without confirmation, creating backups
/workspace/docker/lib/extension-manager.sh deactivate-all --backup --yes
```

**Running individual extensions after activation:**

```bash
# Run a specific activated extension by name
/workspace/scripts/vm-configure.sh --extension rust
/workspace/scripts/vm-configure.sh --extension python

# Run the extension file directly
/workspace/scripts/extensions.d/10-rust.sh

# Run all activated extensions without full VM configuration
/workspace/scripts/vm-configure.sh --extensions-only
```

> [!TIP]
> Use `--extension <name>` to run just one activated extension without re-running all others. If the extension
> isn't activated, you'll receive instructions on how to activate it using the extension-manager.

> [!NOTE]
> Extension 00-init is the core system initialization script (marked as `[PROTECTED]`) and cannot be deactivated.
> This consolidated script handles Turbo Flow, Agent Manager, Tmux Workspace, and Context Management setup.
> Modified extensions automatically create backups when deactivated.

## Using Common Libraries

All extensions have access to shared utilities:

### Core Functions (`common.sh`)

```bash
source /workspace/scripts/lib/common.sh

# Output functions
print_status "Installing tool..."
print_success "Tool installed"
print_error "Installation failed"
print_warning "Optional step skipped"

# Utility functions
if command_exists docker; then
    print_success "Docker is available"
fi

if is_root; then
    print_error "Don't run as root"
    exit 1
fi

# Package management
install_apt_package curl wget git
install_npm_global typescript eslint
install_pip_package requests flask
```

### Tool Installation (`tools.sh`)

```bash
source /workspace/scripts/lib/tools.sh
```

### Workspace Management (`workspace.sh`)

```bash
source /workspace/scripts/lib/workspace.sh
```

## Configuration Examples

### Custom Development Environment

**Full-stack JavaScript:**

```bash
#!/bin/bash
# /workspace/scripts/extensions.d/15-fullstack-js.sh
source /workspace/scripts/lib/common.sh
source /workspace/scripts/lib/tools.sh

print_status "Setting up full-stack JavaScript environment..."

# Node.js with latest LTS
install_nodejs_latest

# Global packages
install_npm_global \
    typescript \
    '@typescript-eslint/parser' \
    '@typescript-eslint/eslint-plugin' \
    prettier \
    nodemon \
    pm2 \
    create-react-app \
    create-next-app \
    '@nestjs/cli'

# Database tools
install_apt_package postgresql-client redis-tools

print_success "Full-stack JavaScript environment ready"
```

**Data Science Setup:**

```bash
#!/bin/bash
# /workspace/scripts/extensions.d/25-datascience.sh
source /workspace/scripts/lib/common.sh
source /workspace/scripts/lib/tools.sh

print_status "Setting up data science environment..."

# Python with pyenv
install_pyenv
pyenv install 3.11.0
pyenv global 3.11.0

# Core packages
install_pip_package \
    jupyter \
    pandas \
    numpy \
    matplotlib \
    seaborn \
    scikit-learn \
    tensorflow \
    torch

# Jupyter setup
jupyter notebook --generate-config
echo "c.NotebookApp.ip = '0.0.0.0'" >> /workspace/developer/.jupyter/jupyter_notebook_config.py

print_success "Data science environment ready"
```

### Agent Configuration

To customize AI agent sources and behavior visit [agents-config.yaml](../docker/config/agents-config.yaml)

> [!Note]
> If you're curious about what is facilitating agent curation, visit [pacphi/claude-code-agent-manager](https://github.com/pacphi/claude-code-agent-manager).

### Tmux Workspace

Customize development workspace layout:

```bash
#!/bin/bash
# /workspace/scripts/extensions.d/35-custom-tmux.sh
source /workspace/scripts/lib/common.sh

print_status "Setting up custom tmux workspace..."

# Custom tmux configuration
cat > /workspace/developer/.tmux.conf << 'EOF'
# Custom key bindings
bind-key r source-file ~/.tmux.conf \; display-message "Config reloaded"
bind-key | split-window -h
bind-key - split-window -v

# Custom status bar
set -g status-bg colour235
set -g status-fg colour136
set -g status-left '#[fg=colour166]#S #[fg=colour245]|'
set -g status-right '#[fg=colour245]%Y-%m-%d %H:%M'

# Window numbering
set -g base-index 1
setw -g pane-base-index 1
EOF

# Custom workspace launcher
cat > /workspace/scripts/lib/my-workspace.sh << 'EOF'
#!/bin/bash
# Custom workspace layout

SESSION_NAME="dev-workspace"

# Create session if it doesn't exist
if ! tmux has-session -t $SESSION_NAME 2>/dev/null; then
    # Main development session
    tmux new-session -d -s $SESSION_NAME -n main

    # Code editing window
    tmux new-window -t $SESSION_NAME -n code
    tmux send-keys -t $SESSION_NAME:code "cd /workspace/projects/active" Enter

    # Server/build window
    tmux new-window -t $SESSION_NAME -n server
    tmux send-keys -t $SESSION_NAME:server "cd /workspace/projects/active" Enter

    # Git/terminal window
    tmux new-window -t $SESSION_NAME -n git
    tmux send-keys -t $SESSION_NAME:git "cd /workspace/projects/active" Enter

    # Select main window
    tmux select-window -t $SESSION_NAME:main
fi

# Attach to session
tmux attach-session -t $SESSION_NAME
EOF

chmod +x /workspace/scripts/lib/my-workspace.sh

print_success "Custom tmux workspace ready"
```

## Environment Variables

### Setting Development Variables

**Project-specific variables:**

```bash
# Create environment file
cat > /workspace/projects/active/my-app/.env << 'EOF'
NODE_ENV=development
API_URL=http://localhost:3000
DATABASE_URL=postgresql://localhost:5432/myapp
REDIS_URL=redis://localhost:6379
EOF

# Load automatically in shell
echo 'if [ -f .env ]; then export $(cat .env | xargs); fi' >> /workspace/developer/.bashrc
```

**Global development variables:**

```bash
# Add to bashrc for all projects
cat >> /workspace/developer/.bashrc << 'EOF'
export EDITOR=code
export PAGER=less
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
EOF
```

### API Keys, Authentication, and LLM Provider Configuration

This section covers secret management patterns, API key configuration for cloud providers and AI tools, and comprehensive guidance for configuring Claude Code to work with alternate LLM providers.

#### Fly.io Secrets Management

Fly.io secrets are injected as runtime environment variables into your VM, providing secure storage for sensitive credentials.

**Basic Commands:**

```bash
# Set individual secrets
flyctl secrets set API_KEY=value -a <app-name>

# Set multiple secrets at once
flyctl secrets set \
  ANTHROPIC_API_KEY=sk-ant-... \
  GITHUB_TOKEN=ghp_... \
  PERPLEXITY_API_KEY=pplx-... \
  -a <app-name>

# List secret names (values hidden)
flyctl secrets list -a <app-name>

# Remove a secret
flyctl secrets unset API_KEY -a <app-name>

# Verify secrets are accessible in VM
flyctl ssh console -a <app-name>
echo $ANTHROPIC_API_KEY
```

**Best Practices:**

- **Secrets vs fly.toml [env]**: Use `flyctl secrets set` for sensitive data (API keys, passwords). Use `fly.toml` [env] section for non-sensitive configuration (feature flags, endpoints).
- **Persistence**: Secrets persist across VM restarts and are only accessible at runtime inside the VM.
- **Deployment**: Set secrets before first deployment or updates will trigger a new deployment.

#### Cloud Provider CLI Authentication

The **85-cloud-tools.sh.example** extension installs multiple cloud provider CLIs. Here's how to configure authentication for each:

**AWS CLI:**

```bash
# Option 1: Access keys via Fly.io secrets
flyctl secrets set AWS_ACCESS_KEY_ID=AKIA... -a <app-name>
flyctl secrets set AWS_SECRET_ACCESS_KEY=... -a <app-name>
flyctl secrets set AWS_DEFAULT_REGION=us-east-1 -a <app-name>

# Option 2: Interactive configuration inside VM
flyctl ssh console -a <app-name>
aws configure

# Option 3: IAM roles (if running on AWS)
# No explicit credentials needed
```

**Azure CLI:**

```bash
# Option 1: Service principal via secrets
flyctl secrets set AZURE_CLIENT_ID=... -a <app-name>
flyctl secrets set AZURE_CLIENT_SECRET=... -a <app-name>
flyctl secrets set AZURE_TENANT_ID=... -a <app-name>

# Option 2: Interactive login inside VM
flyctl ssh console -a <app-name>
az login
```

**Google Cloud CLI:**

```bash
# Option 1: Service account key (create base64-encoded JSON)
# Upload service account JSON to /workspace/gcp-credentials.json
flyctl secrets set GOOGLE_APPLICATION_CREDENTIALS=/workspace/gcp-credentials.json -a <app-name>

# Option 2: Interactive authentication
flyctl ssh console -a <app-name>
gcloud auth login
gcloud config set project PROJECT_ID
```

**Oracle Cloud Infrastructure:**

```bash
# Requires config file at ~/.oci/config
# Run setup inside VM
flyctl ssh console -a <app-name>
oci setup config
```

**Alibaba Cloud:**

```bash
flyctl secrets set ALIBABA_CLOUD_ACCESS_KEY_ID=... -a <app-name>
flyctl secrets set ALIBABA_CLOUD_ACCESS_KEY_SECRET=... -a <app-name>

# Or interactive
flyctl ssh console -a <app-name>
aliyun configure
```

**DigitalOcean:**

```bash
flyctl secrets set DIGITALOCEAN_ACCESS_TOKEN=... -a <app-name>

# Or interactive
flyctl ssh console -a <app-name>
doctl auth init
```

**IBM Cloud:**

```bash
flyctl secrets set IBMCLOUD_API_KEY=... -a <app-name>

# Or interactive
flyctl ssh console -a <app-name>
ibmcloud login
```

#### AI Tool API Keys

The **87-ai-tools.sh.example** extension provides various AI coding assistants. Here's how to configure their API keys:

**Google Gemini CLI:**

```bash
# Get API key: https://makersuite.google.com/app/apikey
flyctl secrets set GOOGLE_GEMINI_API_KEY=... -a <app-name>

# Usage
gemini chat "explain this code"
gemini generate "write unit tests"
```

**Grok CLI:**

```bash
# Requires xAI account
flyctl secrets set GROK_API_KEY=... -a <app-name>

# Usage
grok chat
grok ask "what's the latest in AI?"
```

**Perplexity API (Goalie):**

```bash
# Get API key: https://www.perplexity.ai/settings/api
flyctl secrets set PERPLEXITY_API_KEY=pplx-... -a <app-name>

# Usage
goalie "research topic"
```

**GitHub Copilot:**

```bash
# Requires GitHub account with Copilot subscription
flyctl ssh console -a <app-name>
gh auth login
gh copilot suggest "git command to undo"
```

**AWS Q Developer:**

```bash
# Uses AWS credentials (see AWS CLI section above)
aws q chat
aws q explain "lambda function"
```

**Plandex:**

```bash
# Supports multiple providers via API keys
flyctl secrets set OPENAI_API_KEY=sk-... -a <app-name>
# Or ANTHROPIC_API_KEY, etc.

# Usage
plandex init
plandex plan "add user authentication"
```

**Ollama:**

```bash
# No API keys needed - runs locally
nohup ollama serve > ~/ollama.log 2>&1 &
ollama pull llama3.2
ollama run llama3.2
```

#### Claude Code LLM Provider Configuration

Claude Code natively supports only Anthropic's Claude models. However, you can configure it to work with alternate LLM providers through environment variables and proxy solutions.

##### Native Anthropic Configuration (Default)

```bash
# Set via environment variable (takes priority over Claude.ai subscription)
export ANTHROPIC_API_KEY=sk-ant-...

# Or via Fly.io secrets (recommended)
flyctl secrets set ANTHROPIC_API_KEY=sk-ant-... -a <app-name>

# Get API key: https://console.anthropic.com/
```

**Important:** If `ANTHROPIC_API_KEY` is set, Claude Code will use API-based billing instead of your Claude.ai subscription (Pro/Max/Team/Enterprise).

##### OpenAI-Compatible Providers (Direct Method)

Some providers offer Anthropic-compatible API endpoints that work directly with Claude Code via `ANTHROPIC_BASE_URL`:

**Core Pattern:**

```bash
export ANTHROPIC_BASE_URL=https://api.provider.com/path
export ANTHROPIC_API_KEY=provider-api-key
```

**Z.ai GLM-4.6 (Direct API):**

```bash
# Via Z.ai's native API
flyctl secrets set ANTHROPIC_BASE_URL=https://api.z.ai/api/paas/v4 -a <app-name>
flyctl secrets set ANTHROPIC_API_KEY=your-z-ai-api-key -a <app-name>

# Get API key: https://z.ai (sign up for account)
# Models: glm-4.6, glm-4.5, glm-4.5-air
# Cost: Competitive pricing, check Z.ai pricing page
```

**Z.ai via OpenRouter (Easier):**

```bash
# Access 400+ models including Z.ai through single API
flyctl secrets set ANTHROPIC_BASE_URL=https://openrouter.ai/api/v1 -a <app-name>
flyctl secrets set ANTHROPIC_API_KEY=sk-or-... -a <app-name>

# Get API key: https://openrouter.ai/keys
# Models available:
# - z-ai/glm-4.6
# - z-ai/glm-4.5
# - z-ai/glm-4.5-air:free (free tier!)
```

**DeepSeek (Native Anthropic-Compatible):**

```bash
# DeepSeek offers native Anthropic-compatible API
flyctl secrets set ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic -a <app-name>
flyctl secrets set ANTHROPIC_API_KEY=your-deepseek-key -a <app-name>
flyctl secrets set ANTHROPIC_MODEL=deepseek-chat -a <app-name>
flyctl secrets set ANTHROPIC_SMALL_FAST_MODEL=deepseek-chat -a <app-name>

# Get API key: https://platform.deepseek.com/
# Cost: ~$1/M tokens (85-95% cheaper than Claude)
```

**Other OpenAI-Compatible Providers:**

```bash
# Groq (ultra-fast inference)
export ANTHROPIC_BASE_URL=https://api.groq.com/openai/v1
export ANTHROPIC_API_KEY=gsk-...  # Get from https://console.groq.com

# Together AI (200+ models)
export ANTHROPIC_BASE_URL=https://api.together.xyz/v1
export ANTHROPIC_API_KEY=...  # Get from https://api.together.xyz

# Mistral AI
export ANTHROPIC_BASE_URL=https://api.mistral.ai/v1
export ANTHROPIC_API_KEY=...  # Get from https://console.mistral.ai

# Fireworks AI
export ANTHROPIC_BASE_URL=https://api.fireworks.ai/inference/v1
export ANTHROPIC_API_KEY=fw-...  # Get from https://fireworks.ai
```

##### Proxy Solutions for Advanced Use Cases

When providers don't offer Anthropic-compatible APIs, or when you need advanced features like model-specific routing, fallback chains, or cost optimization, use a proxy solution.

**When to Use Proxies:**

- Provider doesn't have native Anthropic-compatible format (OpenAI, Gemini, etc.)
- Need different models for sonnet vs haiku requests
- Want fallback chains (e.g., AWS Bedrock → Anthropic if quota exceeded)
- Cost optimization across multiple providers
- Enterprise features (monitoring, rate limiting, multi-tenancy)

**Option 1: claude-code-proxy (Simple & Fast)**

A lightweight proxy that translates Claude API requests to OpenAI-compatible APIs.

```bash
# Install on development machine or inside VM
npm install -g claude-code-proxy

# Configure environment variables
export OPENAI_API_KEY=your-provider-key
export OPENAI_BASE_URL=https://api.provider.com/v1
export BIG_MODEL=gpt-4o          # Used for sonnet requests
export SMALL_MODEL=gpt-4o-mini   # Used for haiku requests
export PREFERRED_PROVIDER=openai  # openai, google, or anthropic

# Start proxy (runs on localhost:8082 by default)
claude-code-proxy &

# Configure Claude Code to use proxy
export ANTHROPIC_BASE_URL=http://localhost:8082
export ANTHROPIC_API_KEY=dummy  # Proxy uses OPENAI_API_KEY

# Run Claude Code
claude
```

**Example: Using claude-code-proxy with GLM-4.6 via OpenRouter:**

```bash
# On Fly.io VM
flyctl secrets set OPENAI_API_KEY=sk-or-... -a <app-name>
flyctl secrets set OPENAI_BASE_URL=https://openrouter.ai/api/v1 -a <app-name>
flyctl secrets set BIG_MODEL=z-ai/glm-4.6 -a <app-name>
flyctl secrets set SMALL_MODEL=z-ai/glm-4.5-air:free -a <app-name>
flyctl secrets set ANTHROPIC_BASE_URL=http://localhost:8082 -a <app-name>

# Inside VM (add to startup script)
claude-code-proxy &
```

**Option 2: LiteLLM Proxy (Enterprise-Grade)**

LiteLLM provides a unified API gateway for 100+ LLM providers with advanced features:

- Centralized authentication and usage tracking
- Cost controls and budget limits
- Fallback chains for high availability
- Load balancing across providers
- Multi-tenancy support

```yaml
# /workspace/litellm-config.yaml
model_list:
  # Map Claude models to various providers
  - model_name: claude-sonnet-4
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-v2
      aws_access_key_id: os.environ/AWS_ACCESS_KEY_ID
      aws_secret_access_key: os.environ/AWS_SECRET_ACCESS_KEY

  - model_name: claude-haiku-3
    litellm_params:
      model: gemini/gemini-2.0-flash
      api_key: os.environ/GOOGLE_GEMINI_API_KEY

  # Fallback configuration
  - model_name: claude-sonnet-fallback
    litellm_params:
      model: anthropic/claude-3-5-sonnet
      api_key: os.environ/ANTHROPIC_API_KEY
```

```bash
# Install LiteLLM
pip install litellm[proxy]

# Start proxy with config
litellm --config /workspace/litellm-config.yaml --port 4000

# Configure Claude Code
export ANTHROPIC_BASE_URL=http://localhost:4000
export ANTHROPIC_API_KEY=$LITELLM_MASTER_KEY  # From config

# Run Claude Code
claude
```

**Example: Cost-Optimized Multi-Provider Setup:**

```yaml
# litellm-config.yaml - Route to cheapest provider per task
model_list:
  - model_name: claude-sonnet-4
    litellm_params:
      model: deepseek/deepseek-chat  # $1/M tokens
      api_key: os.environ/DEEPSEEK_API_KEY

  - model_name: claude-haiku-3
    litellm_params:
      model: gemini/gemini-2.0-flash  # Free tier
      api_key: os.environ/GOOGLE_GEMINI_API_KEY

  # Fallback to Anthropic for complex tasks
  - model_name: claude-opus-4
    litellm_params:
      model: anthropic/claude-opus-4
      api_key: os.environ/ANTHROPIC_API_KEY
```

**Option 3: Claude Code Router (Multi-Provider Management)**

Claude Code Router provides intelligent routing with support for multiple providers:

```json
{
  "providers": [
    {
      "name": "openrouter",
      "api_base_url": "https://openrouter.ai/api/v1/chat/completions",
      "api_key": "${OPENROUTER_API_KEY}",
      "models": ["z-ai/glm-4.6", "anthropic/claude-3.5-sonnet"]
    },
    {
      "name": "deepseek",
      "api_base_url": "https://api.deepseek.com/chat/completions",
      "api_key": "${DEEPSEEK_API_KEY}",
      "models": ["deepseek-chat", "deepseek-reasoner"]
    },
    {
      "name": "groq",
      "api_base_url": "https://api.groq.com/openai/v1/chat/completions",
      "api_key": "${GROQ_API_KEY}",
      "models": ["llama-3.1-70b-versatile", "mixtral-8x7b-32768"]
    }
  ]
}
```

#### Complete Setup Examples

**Example 1: Pure Anthropic (Standard)**

```bash
# Simplest setup - just use Anthropic API
flyctl secrets set ANTHROPIC_API_KEY=sk-ant-... -a <app-name>
```

**Example 2: Z.ai GLM-4.6 Direct**

```bash
# Use Z.ai's GLM-4.6 model directly
flyctl secrets set ANTHROPIC_BASE_URL=https://api.z.ai/api/paas/v4 -a <app-name>
flyctl secrets set ANTHROPIC_API_KEY=your-z-ai-key -a <app-name>
```

**Example 3: Z.ai via OpenRouter (Easiest)**

```bash
# Access GLM-4.6 plus 400+ other models
flyctl secrets set ANTHROPIC_BASE_URL=https://openrouter.ai/api/v1 -a <app-name>
flyctl secrets set ANTHROPIC_API_KEY=sk-or-... -a <app-name>
```

**Example 4: Cost-Optimized (DeepSeek + Gemini)**

```bash
# Set up claude-code-proxy with cheap providers
flyctl secrets set OPENAI_API_KEY=your-deepseek-key -a <app-name>
flyctl secrets set OPENAI_BASE_URL=https://api.deepseek.com/v1 -a <app-name>
flyctl secrets set BIG_MODEL=deepseek-chat -a <app-name>
flyctl secrets set SMALL_MODEL=gemini-2.0-flash -a <app-name>
flyctl secrets set GOOGLE_GEMINI_API_KEY=... -a <app-name>
flyctl secrets set ANTHROPIC_BASE_URL=http://localhost:8082 -a <app-name>

# Add to /workspace/scripts/extensions.d/00-init.sh:
# claude-code-proxy &
```

**Example 5: Enterprise Multi-Cloud (LiteLLM)**

```bash
# Set all provider keys
flyctl secrets set AWS_ACCESS_KEY_ID=... -a <app-name>
flyctl secrets set AWS_SECRET_ACCESS_KEY=... -a <app-name>
flyctl secrets set GOOGLE_GEMINI_API_KEY=... -a <app-name>
flyctl secrets set ANTHROPIC_API_KEY=sk-ant-... -a <app-name>
flyctl secrets set LITELLM_MASTER_KEY=$(openssl rand -hex 16) -a <app-name>
flyctl secrets set ANTHROPIC_BASE_URL=http://localhost:4000 -a <app-name>

# Deploy litellm-config.yaml to /workspace/
# Add to startup: litellm --config /workspace/litellm-config.yaml --port 4000 &
```

#### Security Best Practices

1. **Never Commit Secrets**: Add API keys to `.gitignore`. Use `.env.example` templates without actual keys.

2. **Use Fly.io Secrets for Production**: Secrets are encrypted at rest and only accessible inside the VM at runtime.

3. **Rotate Secrets Regularly**: Establish a rotation schedule, especially after team changes or suspected compromise.

4. **Principle of Least Privilege**: Use read-only or limited-scope API keys when possible. For cloud providers, create service accounts with minimal permissions.

5. **Separate Environments**: Use different API keys for development, staging, and production.

6. **Monitor Usage**: Track API usage and costs per provider to detect anomalies or abuse.

7. **Local Development**: For local dev, use `.env` files (add to `.gitignore`) or environment-specific profiles.

```bash
# .env.example (commit this)
ANTHROPIC_API_KEY=sk-ant-your_key_here
GOOGLE_GEMINI_API_KEY=your_key_here
OPENROUTER_API_KEY=sk-or-your_key_here

# .env (DON'T commit this)
ANTHROPIC_API_KEY=sk-ant-actual_secret_key
GOOGLE_GEMINI_API_KEY=actual_secret_key
OPENROUTER_API_KEY=sk-or-actual_secret_key
```

#### Cost Optimization Strategies

1. **Use Cheaper Models for Simple Tasks**: Route haiku/fast-tier requests to cheaper providers like DeepSeek ($1/M) or Gemini Flash (free tier).

2. **Local Models for Development**: Use Ollama with Llama 3.2 or CodeLlama during development to avoid API costs.

3. **Provider Comparison** (per 1M tokens, approximate):
   - **DeepSeek**: $1
   - **Gemini Flash**: Free tier, then $0.35
   - **GLM-4.5-Air**: Free (via OpenRouter)
   - **Claude Haiku**: $3
   - **GPT-4o-mini**: $0.30
   - **Claude Sonnet**: $15
   - **GPT-4o**: $10

4. **Use OpenRouter**: Access 400+ models with unified pricing, often cheaper than going direct.

5. **Implement Caching**: Some providers (Anthropic, OpenAI) support prompt caching to reduce costs on repeated queries.

6. **Free Tiers**: Take advantage of free tiers for development:
   - Gemini 2.0 Flash: Free with limits
   - GLM-4.5-Air: Free via OpenRouter
   - Ollama: Free, runs locally

#### Troubleshooting

**Secrets Not Accessible in VM:**

```bash
# Verify secrets are set
flyctl secrets list -a <app-name>

# Check if secrets are injected
flyctl ssh console -a <app-name>
env | grep API_KEY

# View deployment logs for errors
flyctl logs -a <app-name>

# Secrets require a deployment to take effect
# If you just set them, restart the machine:
flyctl machine restart <machine-id> -a <app-name>
```

**Provider Authentication Fails:**

```bash
# Verify API key format matches provider
# Anthropic: sk-ant-...
# OpenRouter: sk-or-...
# OpenAI: sk-...
# Perplexity: pplx-...

# Test with curl before using with Claude Code
curl -H "Authorization: Bearer $ANTHROPIC_API_KEY" \
  https://api.anthropic.com/v1/messages

# Check base URL (trailing slashes matter!)
echo $ANTHROPIC_BASE_URL
```

**Model Not Found:**

```bash
# Verify model name matches provider's catalog
# Z.ai: glm-4.6, glm-4.5, glm-4.5-air
# DeepSeek: deepseek-chat, deepseek-reasoner
# Groq: llama-3.1-70b-versatile, mixtral-8x7b-32768

# Check provider documentation for model availability
# Some models require special access or approval

# Test model availability with provider's CLI or API docs
```

**Proxy Connection Issues:**

```bash
# Verify proxy is running
ps aux | grep -E 'claude-code-proxy|litellm'
netstat -tuln | grep -E '8082|4000'

# Check proxy logs
tail -f /var/log/claude-code-proxy.log

# Test proxy endpoint
curl http://localhost:8082/health  # or :4000

# Restart proxy if needed
pkill -f claude-code-proxy
claude-code-proxy &
```

**High API Costs:**

```bash
# Review usage by provider
# Most providers offer usage dashboards

# Implement rate limiting with LiteLLM
# Set up budget alerts in provider dashboards

# Switch to cheaper providers for non-critical tasks
# Use local models (Ollama) during development

# Enable prompt caching where supported
# Optimize prompts to reduce token usage
```

**Region-Specific Issues:**

```bash
# Some providers restrict access by region
# Use VPN or region-specific endpoints if needed

# Example: AWS Bedrock requires specific regions
# Set AWS_DEFAULT_REGION appropriately

# Check provider status pages for regional outages
```

## IDE Customization

### VSCode Settings

**Workspace settings:**

```json
// /workspace/projects/active/my-app/.vscode/settings.json
{
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
        "source.fixAll.eslint": true
    },
    "typescript.preferences.importModuleSpecifier": "relative",
    "files.associations": {
        "*.css": "postcss"
    }
}
```

**Remote development settings:**

```json
// ~/.vscode-server/data/Machine/settings.json
{
    "terminal.integrated.shell.linux": "/bin/bash",
    "remote.SSH.remotePlatform": {
        "my-claude-dev.fly.dev": "linux"
    },
    "workbench.colorTheme": "Dark+ (default dark)",
    "editor.minimap.enabled": false
}
```

### Claude Code Hooks

**Automated code formatting:**

```json
// /workspace/developer/.claude/settings.json
{
    "hooks": {
        "user-prompt-submit": "prettier --write .",
        "tool-use-start": "git add -A",
        "tool-use-end": "npm run lint --fix"
    },
    "outputStyles": {
        "default": {
            "codeBlock": {
                "showLineNumbers": true,
                "theme": "github-dark"
            }
        }
    }
}
```

## Project Templates

### Creating Custom Templates

**Template directory structure:**

```bash
mkdir -p /workspace/templates/my-stack
cd /workspace/templates/my-stack

# Project structure
mkdir -p src tests docs config
touch src/index.js tests/index.test.js README.md

# Package.json template
cat > package.json << 'EOF'
{
    "name": "{{PROJECT_NAME}}",
    "version": "1.0.0",
    "scripts": {
        "dev": "nodemon src/index.js",
        "test": "jest",
        "lint": "eslint src/"
    }
}
EOF

# Configuration files
cp /workspace/templates/common/.eslintrc.js .
cp /workspace/templates/common/.gitignore .
```

### CI/CD Integration

**GitHub Actions Setup:**

```bash
#!/bin/bash
# /workspace/scripts/extensions.d/60-github-actions.sh
source /workspace/scripts/lib/common.sh

print_status "Setting up GitHub Actions development tools..."

# Install Act for local testing
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# GitHub CLI for workflow management
if ! command_exists gh; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    apt update && apt install gh -y
fi

# Create GitHub Actions templates
mkdir -p /workspace/templates/github-workflows

cat > /workspace/templates/github-workflows/remote-dev-test.yml << 'EOF'
name: Remote Development Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test-on-fly:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - name: Setup Fly CLI
        uses: superfly/flyctl-actions/setup-flyctl@master

      - name: Deploy test environment
        run: |
          flyctl deploy --remote-only \
            --build-arg ENVIRONMENT=test \
            -a test-claude-dev

      - name: Run tests
        run: |
          flyctl ssh console -a test-claude-dev \
            "cd /workspace/projects/active && npm test"

      - name: Cleanup
        if: always()
        run: |
          flyctl apps destroy test-claude-dev --yes
EOF

cat > /workspace/templates/github-workflows/deploy.yml << 'EOF'
name: Deploy to Development

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - name: Setup Fly CLI
        uses: superfly/flyctl-actions/setup-flyctl@master

      - name: Deploy to development
        run: |
          flyctl deploy --remote-only -a my-claude-dev
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
EOF

print_success "GitHub Actions tools ready"
```

### Kubernetes Development

**Local Kubernetes Setup:**

```bash
#!/bin/bash
# /workspace/scripts/extensions.d/70-kubernetes.sh
source /workspace/scripts/lib/common.sh

print_status "Installing Kubernetes development tools..."

# Install k3s lightweight Kubernetes
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--data-dir /workspace/k3s" sh -

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Configure kubeconfig
mkdir -p /workspace/developer/.kube
cp /etc/rancher/k3s/k3s.yaml /workspace/developer/.kube/config
chown developer:developer /workspace/developer/.kube/config

print_success "Kubernetes environment ready"
```

### Monitoring and Observability

**Monitoring Stack Setup:**

```bash
#!/bin/bash
# /workspace/scripts/extensions.d/75-monitoring.sh
source /workspace/scripts/lib/common.sh

print_status "Setting up monitoring stack..."

# Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v3.5.0/prometheus-3.5.0.linux-amd64.tar.gz
tar xvfz prometheus-*.tar.gz
mv prometheus-*/prometheus /usr/local/bin/
mv prometheus-*/promtool /usr/local/bin/

# Node Exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.9.1/node_exporter-1.9.1.linux-amd64.tar.gz
tar xvfz node_exporter-*.tar.gz
mv node_exporter-*/node_exporter /usr/local/bin/

# Grafana
apt install -y software-properties-common
add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -
apt update
apt install grafana -y

systemctl enable grafana-server
systemctl start grafana-server

# Create Docker Compose for ELK stack
mkdir -p /workspace/docker/monitoring
cat > /workspace/docker/monitoring/docker-compose.yml << 'EOF'
version: '3.8'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:9.1.3
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    volumes:
      - /workspace/data/elasticsearch:/usr/share/elasticsearch/data
    ports:
      - "9200:9200"

  kibana:
    image: docker.elastic.co/kibana/kibana:9.1.3
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch

  logstash:
    image: docker.elastic.co/logstash/logstash:9.1.3
    volumes:
      - ./logstash.conf:/usr/share/logstash/pipeline/logstash.conf
    depends_on:
      - elasticsearch
EOF

print_success "Monitoring stack ready"
```

This comprehensive customization system allows you to tailor the development environment to your specific needs
while maintaining consistency and automation.
