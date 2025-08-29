# IntelliJ Remote Development Setup Guide

## Complete setup guide for connecting IntelliJ IDEA (and other JetBrains IDEs) to your Claude development environment on Fly.io

> **⚡ Need to set up your Fly.io environment first?** Use our automated setup script: `./scripts/vm-setup.sh --app-name my-claude-dev`. See the [Quick Start Guide](QUICKSTART.md) for details.

This guide walks you through connecting IntelliJ IDEA to your Fly.io-hosted Claude development environment using JetBrains Gateway and remote development features.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Install JetBrains Gateway](#install-jetbrains-gateway)
3. [Configure SSH Connection](#configure-ssh-connection)
4. [Connect to Remote VM](#connect-to-remote-vm)
5. [Project Setup](#project-setup)
6. [Plugin Installation](#plugin-installation)
7. [Optimize Performance](#optimize-performance)
8. [Troubleshooting](#troubleshooting)
9. [Tips and Best Practices](#tips-and-best-practices)

## Prerequisites

Before starting, ensure you have:

- ✅ JetBrains account (free or paid)
- ✅ Your Fly.io Claude development environment deployed (use `./scripts/vm-setup.sh` if not)
- ✅ SSH key pair created and configured with Fly.io
- ✅ VM is running (check with `flyctl status -a your-app-name`)

### Quick Environment Setup

If you haven't set up your Fly.io environment yet:

```bash
# Clone the repository
git clone https://github.com/pacphi/claude-flow-on-fly.git
cd claude-flow-on-fly

# Run automated setup
./scripts/vm-setup.sh --app-name my-claude-dev --region iad
```

The script will handle all the Fly.io configuration and provide connection details.

## Install JetBrains Gateway

### Option 1: Standalone Gateway (Recommended)

1. **Download JetBrains Gateway**
   - Visit [JetBrains Gateway](https://www.jetbrains.com/remote-development/gateway/)
   - Download for your operating system
   - Install following the standard installer process

2. **Login to JetBrains Account**
   - Open Gateway
   - Sign in with your JetBrains account
   - Gateway works with both free and paid accounts

### Option 2: Using Existing JetBrains IDE

If you already have IntelliJ IDEA, PyCharm, or other JetBrains IDE:

1. **Open Your IDE**
2. **Access Remote Development**
   - Go to "File" → "Remote Development"
   - Or use "Welcome Screen" → "Remote Development"

## Configure SSH Connection

### Step 1: Prepare SSH Configuration

Create or edit `~/.ssh/config`:

```bash
# Replace 'my-claude-dev' with your actual app name
Host claude-dev
    HostName my-claude-dev.fly.dev
    Port 10022
    User developer
    IdentityFile ~/.ssh/id_rsa
    ServerAliveInterval 60
    ServerAliveCountMax 3
    StrictHostKeyChecking accept-new
    LogLevel ERROR
    Compression yes

# Optional: Add environment-specific hosts
Host claude-dev-staging
    HostName my-claude-dev-staging.fly.dev
    Port 10022
    User developer
    IdentityFile ~/.ssh/id_rsa
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

### Step 2: Test SSH Connection

Verify the connection works:

```bash
ssh claude-dev
```

You should connect successfully and see your VM's welcome message.

## Connect to Remote VM

### Step 1: Launch Gateway

1. **Open JetBrains Gateway**
2. **Create New Connection**
   - Click "New Connection"
   - Select "SSH Connection"

### Step 2: Configure Connection

**Connection Settings:**

- **Host**: `my-claude-dev.fly.dev` (replace with your app name)
- **Port**: `10022`
- **Username**: `developer`
- **Authentication**: Key pair (password disabled)
- **Private key**: Browse to your SSH private key (e.g., `~/.ssh/id_rsa`)

**Advanced Settings:**

- **Connection timeout**: 60 seconds
- **Keep alive**: Enabled
- **Compression**: Enabled

### Step 3: Test Connection

1. Click "Test Connection"
2. Should show "Connection successful"
3. If successful, click "Next"

### Step 4: Choose IDE and Project

1. **Select IDE Type**
   - IntelliJ IDEA Ultimate (for Java, Kotlin, Scala)
   - IntelliJ IDEA Community (for Java, Kotlin)
   - PyCharm Professional (for Python)
   - WebStorm (for JavaScript/TypeScript)
   - Other IDEs as needed

2. **Project Directory**
   - Browse to `/workspace`
   - Select your project folder or create new one
   - Example: `/workspace/projects/active/my-project`

3. **IDE Version**
   - Gateway will suggest the latest stable version
   - Choose the version you prefer

## Project Setup

### Step 1: First Connection

1. **Wait for IDE Installation**
   - Gateway downloads and installs the IDE on the remote VM
   - This takes 3-5 minutes on first connection
   - Progress shown in Gateway window

2. **IDE Launches**
   - Full IDE interface opens
   - Connected to your remote VM
   - All processing happens on the remote machine

### Step 2: First-Time Configuration

**Important**: On your first connection, run the configuration script:

1. **Open Terminal in IDE**
   - View → Tool Windows → Terminal
   - Or use Alt+F12 (Windows/Linux) or Option+F12 (Mac)

2. **Run Configuration Script**

   ```bash
   /workspace/scripts/vm-configure.sh
   ```

3. **Follow the Prompts**
   - Install Node.js, Claude Code, and Claude Flow
   - Configure Git settings (name and email)
   - Set up workspace directory structure
   - Optionally install additional development tools
   - Optionally create project templates

4. **Wait for Completion**
   - The script will show progress as it installs tools
   - This only needs to be done once per VM

### Step 3: Project Configuration

**For Java/Kotlin Projects:**

```bash
# On remote VM (via IDE terminal)
cd /workspace/projects/active
mkdir my-java-project
cd my-java-project

# Initialize project structure
mkdir -p src/main/java/com/example
mkdir -p src/test/java/com/example
mkdir -p src/main/resources

# Create basic pom.xml or build.gradle
```

**For Python Projects:**

```bash
# On remote VM
cd /workspace/projects/active
mkdir my-python-project
cd my-python-project

# Create virtual environment
python3 -m venv venv
source venv/bin/activate
pip install requirements.txt  # if you have one

# Create basic structure
mkdir src tests
touch src/__init__.py
touch requirements.txt
```

**For JavaScript/TypeScript Projects:**

```bash
# On remote VM
cd /workspace/projects/active
mkdir my-web-project
cd my-web-project

# Initialize Node.js project
npm init -y
npm install express  # or your preferred framework

# Create basic structure
mkdir src public
touch src/index.ts
```

### Step 4: Open Project in IDE

1. **File → Open** (or use Welcome screen)
2. Navigate to `/workspace/projects/active/your-project`
3. Click "OK"
4. IDE will index the project files

**Note**: The `/workspace/projects/active` directory is created by the configuration script. If it doesn't exist, you may need to run `/workspace/scripts/vm-configure.sh` first.

## Plugin Installation

### Essential Plugins for Claude Development

**Core Development Plugins:**

- **Docker**: Container support
- **Database Tools**: Database management
- **Git**: Version control (usually pre-installed)
- **Terminal**: Enhanced terminal (usually pre-installed)

**Language-Specific Plugins:**

**For JavaScript/TypeScript:**

- **Node.js**: Node.js development support
- **TypeScript**: Enhanced TypeScript support
- **Prettier**: Code formatting
- **ESLint**: Code linting

**For Python:**

- **Python Community Edition**: Python support (if using Community)
- **Jupyter**: Notebook support
- **Python Security**: Security analysis

**For Java:**

- **Maven**: Maven project support
- **Gradle**: Gradle project support
- **Spring Boot**: Spring framework support

### Installation Method

1. **Open Plugin Marketplace**
   - Go to "File" → "Settings" (or "IntelliJ IDEA" → "Preferences" on Mac)
   - Select "Plugins"

2. **Install Plugins**
   - Search for plugin name
   - Click "Install"
   - Restart IDE if prompted

**Note**: Plugins are installed on the remote VM, not your local machine.

## Optimize Performance

### IDE Settings

**Memory Settings:**

1. Go to "Help" → "Edit Custom VM Options"
2. Add or modify:

   ```bash
   -Xms2048m
   -Xmx4096m
   -XX:ReservedCodeCacheSize=1024m
   ```

**Indexing Optimization:**

1. Go to "File" → "Settings" → "Build, Execution, Deployment" → "Compiler"
2. Increase "Build process heap size" to 2048 MB
3. Enable "Compile independent modules in parallel"

**File Watcher Exclusions:**

1. Go to "File" → "Settings" → "Build, Execution, Deployment" → "Compiler"
2. Add exclusions:

   ```bash
   node_modules
   .git/objects
   dist
   build
   __pycache__
   .venv
   venv
   ```

### Connection Optimization

**SSH Settings in Gateway:**

- **Connection timeout**: 60 seconds
- **Keep alive**: Every 30 seconds
- **Compression**: Enabled
- **X11 forwarding**: Disabled (unless needed)

**Network Optimization:**

```bash
# Add to ~/.ssh/config
Host claude-dev
    TCPKeepAlive yes
    ServerAliveInterval 30
    ServerAliveCountMax 6
    Compression yes
    ControlMaster auto
    ControlPath ~/.ssh/master-%r@%h:%p
    ControlPersist 600
```

## Troubleshooting

For comprehensive troubleshooting including SSH issues, VM management, and performance optimization, see our dedicated [Troubleshooting Guide](TROUBLESHOOTING.md).

### IntelliJ-Specific Issues

#### Issue 1: SSH Connection Problems

For SSH-related issues including:

- Permission denied errors
- Host key verification failures
- Connection timeouts
- Authentication problems

See [SSH Connection Issues](TROUBLESHOOTING.md#ssh-connection-issues) in our Troubleshooting Guide.

**Quick Fix for Host Key Issues:**

```bash
# If you get host key verification failed after VM recreation:
ssh-keygen -R "[your-app-name.fly.dev]:10022"
```

#### Issue 2: Connection Timeout During Setup

**Symptoms**: Gateway hangs during IDE installation

**Solutions**:

1. Check VM status: `flyctl status -a your-app-name`
2. Restart VM if needed: `flyctl machine restart <machine-id> -a your-app-name`
3. Increase timeout in Gateway settings

#### Issue 3: IDE Won't Start

**Symptoms**: IDE installation completes but IDE doesn't launch

**Solutions**:

1. **Check VM Resources**:

   ```bash
   ssh claude-dev
   htop
   df -h
   ```

2. **Upgrade VM Size** (if needed):

   ```bash
   flyctl machine update <machine-id> --vm-size shared-cpu-2x -a your-app-name
   ```

3. **Clear IDE Cache**:

   ```bash
   ssh claude-dev
   rm -rf ~/.cache/JetBrains
   ```

#### Issue 4: Slow Performance

**Symptoms**: IDE is sluggish, high latency

**Solutions**:

1. **Check Network Latency**:

   ```bash
   ping your-app-name.fly.dev
   ```

2. **Optimize SSH Connection**:

   - Enable compression in SSH config
   - Use SSH connection multiplexing

3. **Increase VM Resources**:

   - Upgrade to performance CPU
   - Increase memory allocation

#### Issue 5: Project Not Loading

**Symptoms**: IDE opens but project files don't appear

**Solutions**:

1. **Check Project Path**:

   - Ensure path `/workspace/projects/your-project` exists
   - Verify permissions: `chown -R developer:developer /workspace`

2. **Refresh Project**:

   - File → Reload Gradle/Maven Project
   - Or File → Synchronize

3. **Check Project Structure**:

   - Ensure project has proper configuration files
   - For Maven: `pom.xml`
   - For Gradle: `build.gradle`
   - For Node.js: `package.json`

#### Issue 5: Terminal Not Working

**Symptoms**: Integrated terminal doesn't open or respond

**Solutions**:

1. **Check Shell Configuration**:

   ```bash
   ssh claude-dev
   echo $SHELL
   which bash
   ```

2. **Reset Terminal Settings**:

   - File → Settings → Tools → Terminal
   - Set Shell path to `/bin/bash`

3. **Use External Terminal**:

   - Open separate SSH session if IDE terminal fails

### Debug Connection Issues

**Enable SSH Debug Mode:**

1. Edit your SSH config:

   ```bash
   Host claude-dev
       LogLevel DEBUG3
       # ... other settings
   ```

2. Test connection:

   ```bash
   ssh -v claude-dev
   ```

**Check Gateway Logs:**

1. In Gateway, go to "Help" → "Show Log in Finder/Explorer"
2. Review `idea.log` for connection errors

**Check Remote IDE Logs:**

1. SSH into VM:

   ```bash
   ssh claude-dev
   ls ~/.cache/JetBrains/*/log/
   tail -f ~/.cache/JetBrains/*/log/idea.log
   ```

## Tips and Best Practices

### Development Workflow

1. **Always Use Integrated Terminal**

   ```bash
   # All commands run on remote VM
   cd /workspace/projects/active/my-project

   # Java
   ./mvnw spring-boot:run

   # Python
   source venv/bin/activate
   python main.py

   # Node.js
   npm run dev
   ```

2. **Port Forwarding**

   - IDE automatically forwards common development ports
   - Manually forward additional ports: Tools → Deployment → Configuration

3. **File Synchronization**

   - All files are on remote VM
   - No local synchronization needed
   - Changes are immediate

### Project Organization

```bash
/workspace/
├── projects/
│   ├── active/              # Current projects
│   │   ├── java-api/
│   │   ├── python-ml/
│   │   └── react-frontend/
│   └── archive/             # Completed projects
├── scripts/                 # Utility scripts
├── templates/               # Project templates
└── .config/                 # IDE configurations
```

### Claude Code Integration

1. **Run Claude Code from Terminal**:

   ```bash
   cd /workspace/projects/active/your-project
   claude
   ```

2. **Create Project-Specific CLAUDE.md**:

   ```bash
   cp /workspace/templates/CLAUDE.md.example ./CLAUDE.md
   # Edit with project-specific context
   ```

3. **Use Claude Flow for Complex Tasks**:

   ```bash
   npx claude-flow@alpha init --force
   npx claude-flow@alpha swarm "refactor authentication system"
   ```

### Git Integration

1. **Configure Git on Remote VM**:

   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

2. **SSH Agent Forwarding** (optional):

   ```bash
   # Add to SSH config
   Host claude-dev
       ForwardAgent yes
   ```

3. **Use IDE Git Tools**:

   - VCS → Git → Clone (for new repositories)
   - VCS menu for all Git operations
   - Built-in merge conflict resolution

### Performance Optimization

1. **Monitor Resource Usage**:

   ```bash
   # Check system resources
   htop
   df -h /workspace
   free -h
   ```

2. **IDE Memory Settings**:

   - Help → Edit Custom VM Options
   - Increase heap size for large projects

3. **Exclude Large Directories**:

   - File → Settings → Build → Compiler
   - Add exclusions for `node_modules`, `target`, etc.

### Database Development

1. **Database Tools Plugin**:
   - Built into IntelliJ Ultimate and other professional IDEs
   - Connect to databases running on Fly.io

2. **Connection Configuration**:

   ```bash
   # If database is on same Fly.io app
   Host: localhost (via internal network)
   Port: 5432 (PostgreSQL) or 3306 (MySQL)

   # If database is separate Fly.io app
   Host: database-app.fly.dev
   ```

### Testing and Debugging

1. **Run Configurations**:

   - Create run configurations for your applications
   - Use environment variables from VM

2. **Debugging**:

   - Full debugging support
   - Breakpoints, step-through, variable inspection
   - All debugging happens on remote VM

3. **Testing Frameworks**:

   - JUnit (Java)
   - pytest (Python)
   - Jest (JavaScript)
   - All integrated with IDE

## Advanced Configuration

### Custom IDE Settings

**Code Style Configuration:**

1. File → Settings → Editor → Code Style
2. Configure for your preferred style
3. Export settings to share with team

**Live Templates:**

Create custom code templates:

1. File → Settings → Editor → Live Templates
2. Add templates for common patterns

**External Tools:**

Add custom tools:

1. File → Settings → Tools → External Tools
2. Add Claude Code, backup scripts, etc.

### Multi-Project Workspace

**Working with Multiple Projects:**

1. **File → Open** multiple projects
2. Each opens in separate window
3. Or use "Add as Module" for related projects

**Project Switching:**

- Window → Next Project Window
- Or use project switcher (Cmd/Ctrl + Alt + brackets)

### Team Collaboration

1. **Shared Code Styles**:

   - Export IDE settings
   - Commit `.idea/codeStyles/` to Git

2. **Shared Run Configurations**:

   - Store in `.idea/runConfigurations/`
   - Commit to Git for team sharing

3. **Plugin Standardization**:

   - Document required plugins
   - Use `.idea/externalDependencies.xml`

## IDE-Specific Notes

### IntelliJ IDEA Ultimate vs Community

**Ultimate Features:**

- Database tools
- Web development
- Spring framework support
- Application servers
- Remote development (built-in)

**Community Features:**

- Java, Kotlin, Scala development
- Maven, Gradle support
- Git integration
- Basic debugging

### Other JetBrains IDEs

**PyCharm Professional**:

- Full Python development
- Web frameworks (Django, Flask)
- Database tools
- Scientific tools (Jupyter, Anaconda)

**WebStorm**:

- JavaScript, TypeScript development
- Node.js support
- React, Vue, Angular frameworks
- Testing frameworks

**DataGrip**:

- Database-focused IDE
- SQL development
- Multiple database support

## Terminal Utilities

The environment provides helpful utilities you can use directly in IntelliJ's integrated terminal:

### Using Common Libraries

Source the common library for colored output and utilities:

```bash
# Source the common library for colored output
source /workspace/scripts/lib/common.sh

# Use print functions in your terminal
print_success "Build completed!"
print_error "Tests failed"
print_warning "Low disk space"
print_status "Running deployment..."
```

### Available Utilities

**Common Functions:**

```bash
# Check if a command exists
if command_exists docker; then
    echo "Docker is available"
fi

# Create directories with proper ownership
create_directory "/workspace/my-project"

# Run commands with retry logic
retry_with_backoff 3 2 "mvn clean install"
```

**Workspace Functions:**

```bash
# Source workspace utilities
source /workspace/scripts/lib/workspace.sh

# Create a new project
setup_workspace_structure
create_project_templates
```

**Git Utilities:**

```bash
# Source Git utilities
source /workspace/scripts/lib/git.sh

# Setup Git aliases and hooks
setup_git_aliases
setup_git_hooks
```

**Quick Commands:**

```bash
# System status
/workspace/scripts/system-status.sh

# Backup workspace
/workspace/scripts/backup.sh

# Create new project
/workspace/scripts/new-project.sh my-app java
```

## Summary

With this setup, you have:

- ✅ IntelliJ IDEA (or other JetBrains IDE) connected to remote VM
- ✅ Full IDE functionality with debugging, testing, and database tools
- ✅ Access to Claude Code and Claude Flow on remote VM
- ✅ Persistent workspace with project organization
- ✅ Optimized performance and connection settings

Your remote development environment provides the full power of JetBrains IDEs while leveraging Fly.io's scalable infrastructure and Claude's AI assistance.

## Related Documentation

- **[Quick Start Guide](QUICKSTART.md)** - Fast-track setup with automated scripts
- **[Complete Setup Guide](SETUP.md)** - Detailed manual setup instructions
- **[VSCode Setup](VSCODE.md)** - Visual Studio Code remote development
