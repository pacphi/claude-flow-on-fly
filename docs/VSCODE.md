# VS Code Remote Development Setup

## Connect VS Code to your Claude development environment on Fly.io

> **📋 Complete the common setup first:** See [IDE Setup Guide](IDE_SETUP.md) for prerequisites, SSH configuration,
> and VM setup before proceeding.

This guide covers VS Code-specific setup using the Remote-SSH extension.

## Table of Contents

1. [Install Remote-SSH Extension](#install-remote-ssh-extension)
2. [Connect to Remote VM](#connect-to-remote-vm)
3. [Install Remote Extensions](#install-remote-extensions)
4. [VS Code Optimization](#vs-code-optimization)
5. [VS Code Troubleshooting](#vs-code-troubleshooting)
6. [Advanced Configuration](#advanced-configuration)

## Install Remote-SSH Extension

1. **Open VS Code Extensions**
   - Click Extensions icon (⇧⌘X on Mac, Ctrl+Shift+X on Windows/Linux)
   - Search for "Remote - SSH"
   - Install the official "Remote - SSH" extension by Microsoft

2. **Verify Installation**
   - You should see a remote indicator (`><`) in the bottom-left corner

## Connect to Remote VM

> **📋 Prerequisites:** Complete the [IDE Setup Guide](IDE_SETUP.md) first to configure SSH and run the
> VM configuration script.

### Connection Methods

#### Method 1: Command Palette

1. Press `Cmd+Shift+P` (Mac) or `Ctrl+Shift+P` (Windows/Linux)
2. Type "Remote-SSH: Connect to Host"
3. Select your configured host (`claude-dev`)

#### Method 2: Remote Explorer

1. Click Remote Explorer icon in sidebar
2. Find your host under "SSH TARGETS"
3. Click the folder icon next to your host

#### Method 3: Status Bar

1. Click remote indicator (`><`) in bottom-left
2. Select "Connect to Host..."
3. Choose your configured host

### First Connection

1. **VS Code Server Installation**
   - VS Code installs the server on remote VM (1-2 minutes)
   - Progress shown in bottom-right corner
   - New VS Code window opens when complete

2. **Open Workspace**
   - Click "Open Folder" or File → Open Folder
   - Navigate to `/workspace/projects/active`
   - Select your project directory

## Install Remote Extensions

### Essential Extensions

**Core Development:**

- `ms-vscode.vscode-typescript-next` - TypeScript support
- `ms-python.python` - Python development
- `esbenp.prettier-vscode` - Code formatting
- `ms-vscode.vscode-eslint` - JavaScript linting
- `ms-vscode.vscode-json` - JSON support

**Additional:**

- `ms-vscode.vscode-docker` - Docker support
- `github.copilot` - AI coding assistant
- `ms-vscode.live-share` - Collaborative editing

### Installation

1. **Extensions Panel:** Open Extensions (⇧⌘X) → Search → "Install in SSH: claude-dev"
2. **Command Line:** `code --install-extension extension-name`
3. **Settings Sync:** Enable to automatically sync extensions

**Note:** Extensions install on the remote VM, not locally.

## VS Code Optimization

### Connection Settings

Add to VS Code's `settings.json`:

```json
{
  "remote.SSH.connectTimeout": 60,
  "remote.SSH.keepAlive": 30,
  "remote.SSH.maxReconnectionAttempts": 3,
  "remote.autoForwardPorts": false,
  "files.watcherExclude": {
    "**/node_modules/**": true,
    "**/.git/objects/**": true,
    "**/dist/**": true,
    "**/build/**": true,
    "**/__pycache__/**": true
  }
}
```

### Performance Tips

- **Use Remote Terminal:** All commands run on remote VM
- **Disable Auto Port Forwarding:** Forward only needed ports
- **Work in `/workspace`:** Use persistent volume for all files
- **Exclude Large Directories:** Reduces CPU and improves responsiveness

## VS Code Troubleshooting

> **📋 General Issues:** See [IDE Setup Guide](IDE_SETUP.md#common-troubleshooting) and
> [Troubleshooting Guide](TROUBLESHOOTING.md) for SSH and VM issues.

### VS Code-Specific Issues

#### Server Installation Fails

**Symptoms:** Server installation hangs or fails

**Solutions:**

1. Wait for VM to fully start (30-60 seconds)
2. Clear remote server: `Cmd+Shift+P` → "Remote-SSH: Kill VS Code Server on Host"
3. Reconnect

#### Extensions Don't Work

**Symptoms:** Extensions show errors or don't activate

**Solutions:**

1. Ensure extensions installed on remote, not locally
2. Reload window: `Cmd+Shift+P` → "Developer: Reload Window"
3. Check extension compatibility with remote development

#### Slow Performance

**Solutions:**

1. Check VM resources: `htop` on remote VM
2. Exclude large directories from file watcher
3. Close unused tabs and panels
4. Upgrade VM size if needed

#### File Changes Not Detected

**Solutions:**

1. Use VS Code's integrated terminal for dev commands
2. Check development server running on remote VM
3. Verify port forwarding configuration

### Debug Tools

**VS Code Remote Logs:**

- `Cmd+Shift+P` → "Remote-SSH: Show Log"

**Test Connection:**

```bash
ssh -v claude-dev 'echo "Connection works"'
```

## VS Code Best Practices

### Development Workflow

1. **Use Integrated Terminal**

   ```bash
   # All commands run on remote VM
   cd /workspace/projects/active/my-project
   npm run dev
   ```

2. **Port Forwarding**
   - VS Code auto-prompts to forward dev server ports
   - Click "Forward Port" to access from local browser
   - Manually forward: Ports panel in bottom bar

3. **File Management**
   - Work directly in `/workspace` (persistent)
   - Use File Explorer for navigation
   - Auto-save recommended: `"files.autoSave": "afterDelay"`

### Recommended Settings

```json
{
  "files.autoSave": "afterDelay",
  "files.autoSaveDelay": 5000,
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true
  },
  "terminal.integrated.persistentSessionReviveProcess": "onExit"
}
```

### Multi-Project Workflow

- **Multiple Windows:** File → New Window → Connect to same host
- **Workspace Files:** Save multi-root workspaces for related projects
- **Project Switching:** File → Open Recent

## Advanced Configuration

### Project-Specific Settings

Create `.vscode/settings.json` in your project:

```json
{
  "python.defaultInterpreterPath": "/usr/bin/python3",
  "eslint.workingDirectories": ["src"],
  "prettier.configPath": ".prettierrc",
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true,
    "source.organizeImports": true
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
      "program": "${workspaceFolder}/src/index.js"
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

### Custom Tasks

Create `.vscode/tasks.json`:

```json
{
  "version": "2.0.0",
  "tasks": [
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

VS Code is now connected to your remote Claude development environment with:

- ✅ Full IDE functionality with debugging and extensions
- ✅ Remote development on persistent Fly.io infrastructure
- ✅ Integrated access to Claude Code and Claude Flow
- ✅ Optimized performance and connection settings

## Related Documentation

- **[IDE Setup Guide](IDE_SETUP.md)** - Common setup and utilities
- **[IntelliJ Setup](INTELLIJ.md)** - JetBrains IDE alternative
- **[Troubleshooting Guide](TROUBLESHOOTING.md)** - Problem resolution
