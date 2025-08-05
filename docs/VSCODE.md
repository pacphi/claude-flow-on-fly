# VSCode Remote Development Setup Guide

## Complete setup guide for connecting VSCode to your Claude development environment on Fly.io

> **⚡ Need to set up your Fly.io environment first?** Use our automated setup script: `./scripts/vm-setup.sh --app-name my-claude-dev`. See the [Quick Start Guide](../QUICKSTART.md) for details.

This guide walks you through connecting Visual Studio Code to your Fly.io-hosted Claude development environment using the Remote-SSH extension.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Install Remote-SSH Extension](#install-remote-ssh-extension)
3. [Configure SSH Connection](#configure-ssh-connection)
4. [Connect to Remote VM](#connect-to-remote-vm)
5. [Install Remote Extensions](#install-remote-extensions)
6. [Optimize Performance](#optimize-performance)
7. [Troubleshooting](#troubleshooting)
8. [Tips and Best Practices](#tips-and-best-practices)

## Prerequisites

Before starting, ensure you have:

- ✅ VSCode installed (latest version recommended)
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

## Install Remote-SSH Extension

### Step 1: Open VSCode Extensions

1. Open VSCode
2. Click the Extensions icon (⇧⌘X on Mac, Ctrl+Shift+X on Windows/Linux)
3. Search for "Remote - SSH"
4. Install the official "Remote - SSH" extension by Microsoft

### Step 2: Verify Installation

- You should see a remote indicator in the bottom-left corner of VSCode
- The remote indicator looks like: `><`

## Configure SSH Connection

### Step 1: Open SSH Configuration

**Method 1: Using Command Palette**
1. Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux)
2. Type "Remote-SSH: Open SSH Configuration File"
3. Select your SSH config file (usually `~/.ssh/config`)

**Method 2: Direct File Edit**
1. Open `~/.ssh/config` in any text editor
2. If the file doesn't exist, create it

### Step 2: Add Configuration

Add this configuration to your `~/.ssh/config` file:

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

# Optional: Add a shorter alias
Host dev
    HostName my-claude-dev.fly.dev
    Port 10022
    User developer
    IdentityFile ~/.ssh/id_rsa
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

### Step 3: Test SSH Connection

Before using VSCode, test the SSH connection:

```bash
ssh claude-dev
```

You should connect successfully and see the welcome message from your VM.

## Connect to Remote VM

### Step 1: Connect Using Command Palette

1. Open VSCode
2. Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux)
3. Type "Remote-SSH: Connect to Host"
4. Select your configured host (`claude-dev`)

### Step 2: Alternative Connection Methods

**Method 1: Remote Explorer**
1. Click the Remote Explorer icon in the sidebar
2. Find your host under "SSH TARGETS"
3. Click the folder icon next to your host

**Method 2: Status Bar**
1. Click the remote indicator (`><`) in the bottom-left corner
2. Select "Connect to Host..."
3. Choose your configured host

### Step 3: First Connection Setup

On first connection:
1. VSCode will install the VS Code Server on the remote machine
2. This process takes 1-2 minutes
3. You'll see progress in the bottom-right corner
4. A new VSCode window will open connected to the remote VM

### Step 4: First-Time Configuration

**Important**: On your first connection, run the configuration script:

1. Open the integrated terminal in VSCode (Terminal → New Terminal)
2. Run the configuration script:
   ```bash
   /workspace/scripts/vm-configure.sh
   ```
3. Follow the prompts to:
   - Install Node.js, Claude Code, and Claude Flow
   - Configure Git settings
   - Set up workspace structure
   - Optionally install development tools

### Step 5: Open Workspace

1. After configuration, click "Open Folder" (or File → Open Folder)
2. Navigate to `/workspace/projects/active` (created by the config script)
3. Select your project directory or create a new one

## Install Remote Extensions

### Essential Extensions for Claude Development

After connecting, install these extensions on the remote VM:

**Core Development Extensions:**
```
ms-vscode.vscode-typescript-next
ms-python.python
bradlc.vscode-tailwindcss
esbenp.prettier-vscode
ms-vscode.vscode-eslint
ms-vscode.vscode-json
```

**Additional Helpful Extensions:**
```
ms-vscode.remote-ssh-edit
ms-vscode.remote-explorer
ms-vscode.vscode-docker
github.copilot (if you have access)
ms-vscode.live-share
```

### Installation Methods

**Method 1: Via Extensions Panel**
1. Open Extensions (⇧⌘X)
2. Search for extension name
3. Click "Install in SSH: claude-dev"

**Method 2: Via Command Line (on remote VM)**
```bash
# After SSH into the VM
code --install-extension ms-python.python
code --install-extension esbenp.prettier-vscode
```

**Method 3: Sync Settings**
- Enable Settings Sync in VSCode to automatically sync extensions

## Optimize Performance

### Connection Settings

Add these settings to VSCode's `settings.json`:

```json
{
  "remote.SSH.connectTimeout": 60,
  "remote.SSH.keepAlive": 30,
  "remote.SSH.maxReconnectionAttempts": 3,
  "remote.autoForwardPorts": false,
  "files.watcherExclude": {
    "**/node_modules/**": true,
    "**/.git/objects/**": true,
    "**/.git/subtree-cache/**": true,
    "**/dist/**": true,
    "**/build/**": true
  }
}
```

### Performance Tips

1. **Exclude Large Directories**
   - Add `node_modules`, `dist`, `.git/objects` to file watcher exclusions
   - This reduces CPU usage and improves responsiveness

2. **Use Remote Terminal**
   - Always use VSCode's integrated terminal when connected
   - This runs commands on the remote VM, not locally

3. **Forward Only Necessary Ports**
   - Disable auto port forwarding
   - Manually forward only the ports you need

4. **Optimize File Sync**
   - Work directly in `/workspace` (persistent volume)
   - Avoid editing files outside the workspace

## Troubleshooting

### Common Issues and Solutions

#### Issue 1: Connection Timeout
**Symptoms**: VSCode fails to connect, timeout errors
**Solutions**:
1. Check if VM is running: `flyctl status -a your-app-name`
2. Start VM if stopped: `flyctl machine start <machine-id> -a your-app-name`
3. Test SSH connection: `ssh claude-dev`
4. Check SSH config syntax

#### Issue 2: VS Code Server Installation Fails
**Symptoms**: Server installation hangs or fails
**Solutions**:
1. Wait for VM to fully start (can take 30-60 seconds)
2. Try connecting again
3. Clear remote server: Press `Cmd+Shift+P` → "Remote-SSH: Kill VS Code Server on Host"
4. Reconnect

#### Issue 3: Extensions Don't Work
**Symptoms**: Extensions show errors or don't activate
**Solutions**:
1. Ensure extensions are installed on remote, not locally
2. Reload window: `Cmd+Shift+P` → "Developer: Reload Window"
3. Check extension compatibility with remote development

#### Issue 4: Slow Performance
**Symptoms**: Sluggish editing, slow file operations
**Solutions**:
1. Check VM resources: `htop` on remote VM
2. Upgrade VM size if needed
3. Exclude large directories from file watcher
4. Close unused tabs and panels

#### Issue 5: File Changes Not Detected
**Symptoms**: Hot reload doesn't work, changes not reflected
**Solutions**:
1. Use VSCode's integrated terminal for development commands
2. Check if development server is running on remote VM
3. Verify port forwarding configuration

### Debug Connection Issues

**Enable SSH Debug Logging**:
```bash
# Add to ~/.ssh/config for your host
LogLevel DEBUG3
```

**Check VSCode Remote Logs**:
1. Press `Cmd+Shift+P` → "Remote-SSH: Show Log"
2. Review connection logs for errors

**Test SSH from Terminal**:
```bash
# Test connection with verbose output
ssh -v claude-dev

# Test specific components
ssh claude-dev 'echo "Connection works"'
ssh claude-dev 'ls /workspace'
```

## Tips and Best Practices

### Development Workflow

1. **Always Use Remote Terminal**
   ```bash
   # Run all commands in VSCode's integrated terminal
   cd /workspace/my-project
   npm install
   npm run dev
   ```

2. **Port Forwarding for Development Servers**
   - When running a dev server (e.g., port 3000)
   - VSCode will automatically prompt to forward the port
   - Click "Forward Port" to access from your local browser

3. **File Organization**
   ```
   /workspace/
   ├── projects/
   │   ├── active/          # Current projects
   │   └── archive/         # Completed projects
   ├── scripts/             # Utility scripts
   └── .config/             # Configuration files
   ```

### Git Workflow

1. **Configure Git on Remote VM**:
   ```bash
   git config --global user.name "Your Name"
   git config --global user.email "your.email@example.com"
   ```

2. **SSH Agent Forwarding** (optional):
   Add to SSH config for seamless Git operations:
   ```bash
   Host claude-dev
       ForwardAgent yes
       # ... other settings
   ```

### Claude Code Integration

1. **Run Claude Code from VSCode Terminal**:
   ```bash
   cd /workspace/your-project
   claude
   ```

2. **Create CLAUDE.md in Project Root**:
   - Use the template from `/workspace/templates/CLAUDE.md.template`
   - Customize for your specific project

3. **Use Claude Flow for Multi-Agent Development**:
   ```bash
   cd /workspace/your-project
   npx claude-flow@alpha init --force
   npx claude-flow@alpha swarm "your development task"
   ```

### Session Management

1. **Use tmux for Persistent Sessions**:
   ```bash
   # Create named session
   tmux new-session -s dev

   # Detach: Ctrl+B, then D
   # Reattach: tmux attach -t dev
   ```

2. **Save Work Regularly**:
   - All work in `/workspace` is persistent
   - Use Git commits frequently
   - Run backup script periodically

### Performance Optimization

1. **Monitor Resource Usage**:
   ```bash
   # Check system resources
   htop
   df -h /workspace
   ```

2. **Optimize VSCode Settings**:
   ```json
   {
     "files.autoSave": "afterDelay",
     "files.autoSaveDelay": 5000,
     "editor.formatOnSave": true,
     "editor.codeActionsOnSave": {
       "source.fixAll.eslint": true
     }
   }
   ```

### Security Best Practices

1. **Keep SSH Keys Secure**:
   - Use strong passphrases
   - Rotate keys regularly
   - Don't share private keys

2. **Use Environment Variables for Secrets**:
   ```bash
   # Set secrets in Fly.io
   flyctl secrets set API_KEY=your_secret -a your-app-name
   ```

3. **Regular Security Updates**:
   ```bash
   # Update system packages (run periodically)
   sudo apt update && sudo apt upgrade
   ```

## Advanced Configuration

### Custom VSCode Workspace Settings

Create `.vscode/settings.json` in your project:

```json
{
  "python.defaultInterpreterPath": "/usr/bin/python3",
  "python.terminal.activateEnvironment": true,
  "eslint.workingDirectories": ["src"],
  "prettier.configPath": ".prettierrc",
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true,
    "source.organizeImports": true
  },
  "files.exclude": {
    "**/node_modules": true,
    "**/.git": true,
    "**/dist": true,
    "**/build": true
  }
}
```

### Launch Configurations

Create `.vscode/launch.json` for debugging:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Launch Node.js",
      "type": "node",
      "request": "launch",
      "program": "${workspaceFolder}/src/index.js",
      "env": {
        "NODE_ENV": "development"
      }
    },
    {
      "name": "Python Debugger",
      "type": "python",
      "request": "launch",
      "program": "${workspaceFolder}/main.py",
      "console": "integratedTerminal"
    }
  ]
}
```

### Tasks Configuration

Create `.vscode/tasks.json` for custom tasks:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "npm: install",
      "type": "shell",
      "command": "npm install",
      "group": "build",
      "presentation": {
        "panel": "new"
      }
    },
    {
      "label": "npm: dev",
      "type": "shell",
      "command": "npm run dev",
      "group": "build",
      "isBackground": true
    },
    {
      "label": "backup workspace",
      "type": "shell",
      "command": "/workspace/scripts/backup.sh",
      "group": "build"
    }
  ]
}
```

## Summary

With this setup, you have:

- ✅ VSCode connected to your remote Claude development environment
- ✅ Full IDE functionality with syntax highlighting, debugging, and extensions
- ✅ Access to Claude Code and Claude Flow on the remote VM
- ✅ Persistent workspace that survives VM restarts
- ✅ Optimized performance and connection settings

Your development environment is now ready for AI-assisted coding with Claude tools, all running securely on Fly.io with persistent storage and cost-effective auto-scaling.

## Related Documentation

- **[Quick Start Guide](../QUICKSTART.md)** - Fast-track setup with automated scripts
- **[Complete Setup Guide](../SETUP.md)** - Detailed manual setup instructions
- **[IntelliJ Setup](INTELLIJ.md)** - JetBrains IDE remote development