# Customization

## Extension System

The environment supports extensive customization through a modular extension system that allows you to add tools, configure environments, and automate setup tasks.

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
- **01-04*** - Core tool installations
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

# Run extensions only
/workspace/scripts/vm-configure.sh --extensions-only
```

## Built-in Extension Examples

### Language Tools

**Rust Toolchain:**

```bash
# Enable Rust development
cp /workspace/scripts/extensions.d/10-rust.sh.example \
   /workspace/scripts/extensions.d/10-rust.sh

# Customize installation
vim /workspace/scripts/extensions.d/10-rust.sh
```

**Go Development:**

```bash
# Enable Go toolchain
cp /workspace/scripts/extensions.d/20-golang.sh.example \
   /workspace/scripts/extensions.d/20-golang.sh
```

**Python Tools:**

```bash
# Enable advanced Python setup
cp /workspace/scripts/extensions.d/05-python.sh.example \
   /workspace/scripts/extensions.d/05-python.sh
```

### Infrastructure Tools

**Docker Utilities:**

```bash
# Enable Docker development
cp /workspace/scripts/extensions.d/30-docker.sh.example \
   /workspace/scripts/extensions.d/30-docker.sh
```

**JVM Languages:**

```bash
# Java, Scala, Kotlin support
cp /workspace/scripts/extensions.d/40-jvm.sh.example \
   /workspace/scripts/extensions.d/40-jvm.sh
```

**Infrastructure Tools:**

```bash
# Terraform, kubectl, cloud CLIs
cp /workspace/scripts/extensions.d/80-infra-tools.sh.example \
   /workspace/scripts/extensions.d/80-infra-tools.sh
```

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

### Secret Management

**Using Fly.io secrets:**

```bash
# Set secrets at deployment time
flyctl secrets set OPENAI_API_KEY=sk-... -a my-claude-dev
flyctl secrets set GITHUB_TOKEN=ghp_... -a my-claude-dev
flyctl secrets set DATABASE_PASSWORD=secret123 -a my-claude-dev

# Access in scripts
echo $OPENAI_API_KEY  # Available as environment variable
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

This comprehensive customization system allows you to tailor the development environment to your specific needs while maintaining consistency and automation.
