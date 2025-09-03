# 🛠️ Troubleshooting Guide

This comprehensive guide helps resolve common issues with your Claude development environment on Fly.io.

## Table of Contents

1. [SSH Connection Issues](#ssh-connection-issues)
2. [Creating and Managing SSH Keys](#creating-and-managing-ssh-keys)
3. [VM Management Issues](#vm-management-issues)
4. [Configuration Problems](#configuration-problems)
5. [IDE Connection Issues](#ide-connection-issues)
6. [Performance Issues](#performance-issues)
7. [Cost and Billing Issues](#cost-and-billing-issues)
8. [Claude Tools Issues](#claude-tools-issues)

## SSH Connection Issues

### Host Key Verification Failed

**Problem:** After tearing down and recreating a VM with the same name, you get:

```bash
kex_exchange_identification: read: Connection reset by peer
Connection reset by 2a09:8280:1::8c:fcda:0 port 10022
```

**Solution:** Remove the old host key from your known_hosts file:

```bash
# For standard hostnames
ssh-keygen -R "[my-claude-dev.fly.dev]:10022"

# If you have IPv6 addresses cached
ssh-keygen -R "[2a09:8280:1::8c:fcda:0]:10022"

# Then retry your connection
ssh developer@my-claude-dev.fly.dev -p 10022
```

**Why this happens:** SSH stores host keys to prevent man-in-the-middle attacks. When you recreate a VM, it gets a new host key, causing a mismatch with the stored key.

### Connection Refused

**Problem:** SSH connection is immediately refused.

**Solutions:**

1. Check if the VM is running:

   ```bash
   flyctl status -a my-claude-dev
   flyctl machine list -a my-claude-dev
   ```

2. If the VM is suspended, resume it:

   ```bash
   ./scripts/vm-resume.sh --app-name my-claude-dev
   # Wait 30-60 seconds for the VM to fully start
   ```

3. Check VM logs for errors:

   ```bash
   flyctl logs -a my-claude-dev
   ```

### Connection Timeout

**Problem:** SSH connection hangs and eventually times out.

**Solutions:**

1. Test with verbose output to see where it fails:

   ```bash
   ssh -vvv developer@my-claude-dev.fly.dev -p 10022
   ```

2. Check if the app is accessible:

   ```bash
   flyctl ping -a my-claude-dev
   ```

3. Verify your firewall isn't blocking port 10022:

   ```bash
   # Test connectivity
   nc -zv my-claude-dev.fly.dev 10022
   ```

### Permission Denied (publickey)

**Problem:** SSH rejects your authentication.

**Solutions:**

1. Verify you're using the correct private key:

   ```bash
   ssh -i ~/.ssh/id_rsa developer@my-claude-dev.fly.dev -p 10022
   ```

2. Check key permissions (must be 600 for private keys):

   ```bash
   ls -la ~/.ssh/id_rsa
   chmod 600 ~/.ssh/id_rsa
   ```

3. Ensure your public key was deployed:

   ```bash
   flyctl ssh console -a my-claude-dev
   cat /workspace/developer/.ssh/authorized_keys
   ```

## Creating and Managing SSH Keys

If you don't have SSH keys yet, follow these steps:

### Creating New SSH Keys

**Option 1: Ed25519 (Recommended - more secure and faster)**

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "your-email@example.com"
```

**Option 2: RSA (broader compatibility)**

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -C "your-email@example.com"
```

### Setting Correct Permissions

SSH requires specific permissions for security:

```bash
# For RSA keys
chmod 600 ~/.ssh/id_rsa        # Private key - owner read/write only
chmod 644 ~/.ssh/id_rsa.pub    # Public key - readable by others

# For Ed25519 keys
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub

# SSH directory itself
chmod 700 ~/.ssh
```

### Common SSH Key Mistakes

1. **Using the wrong key file in SSH config**
   - ❌ Wrong: `IdentityFile ~/.ssh/id_rsa.pub` (public key)
   - ✅ Correct: `IdentityFile ~/.ssh/id_rsa` (private key)

2. **Incorrect permissions**
   - SSH will refuse to use keys with incorrect permissions
   - Private keys must be 600 (read/write for owner only)

3. **Multiple keys confusion**
   - Use `ssh -i` to specify which key to use
   - Or configure in `~/.ssh/config` for automatic selection

### Adding Keys to SSH Agent

For convenience, add your key to the SSH agent:

```bash
# Start the agent
eval "$(ssh-agent -s)"

# Add your key
ssh-add ~/.ssh/id_rsa
# or
ssh-add ~/.ssh/id_ed25519

# List loaded keys
ssh-add -l
```

## VM Management Issues

### VM Won't Start

**Problem:** The VM fails to start or crashes immediately.

**Solutions:**

1. Check machine status and logs:

   ```bash
   flyctl status -a my-claude-dev
   flyctl machine list -a my-claude-dev
   flyctl logs -a my-claude-dev
   ```

2. Restart the machine:

   ```bash
   flyctl machine restart <machine-id> -a my-claude-dev
   ```

3. Check resource allocation:

   ```bash
   flyctl scale show -a my-claude-dev
   ```

### VM Suspended Unexpectedly

**Problem:** VM suspends while you're working.

**Solutions:**

1. Adjust auto-stop settings in `fly.toml`:

   ```toml
   [services.concurrency]
   auto_stop_machines = "suspend"
   auto_start_machines = true
   min_machines_running = 0
   ```

2. Keep VM running with activity:

   ```bash
   # Run a keep-alive command
   while true; do date; sleep 300; done
   ```

### Volume Not Mounting

**Problem:** `/workspace` directory is empty or missing.

**Solutions:**

1. Check volume attachment:

   ```bash
   flyctl volumes list -a my-claude-dev
   ```

2. Verify mount in machine config:

   ```bash
   flyctl config show -a my-claude-dev
   ```

3. Restart with volume check:

   ```bash
   flyctl machine restart <machine-id> -a my-claude-dev --force
   ```

## Configuration Problems

### Scripts Not Found

**Problem:** Configuration scripts are missing in `/workspace/scripts/`.

**Solutions:**

1. The scripts are created on first VM deployment. If missing:

   ```bash
   # Redeploy the application
   flyctl deploy -a my-claude-dev
   ```

2. Check if volume is mounted correctly:

   ```bash
   df -h /workspace
   ls -la /workspace/
   ```

### Node.js/npm Not Available

**Problem:** `node` or `npm` commands not found.

**Solution:** Run the configuration script:

```bash
/workspace/scripts/vm-configure.sh
source ~/.bashrc
```

### Git Configuration Missing

**Problem:** Git commits fail with "Please tell me who you are" error.

**Solution:** The configuration script sets this up, but you can manually configure:

```bash
git config --global user.name "Your Name"
git config --global user.email "your-email@example.com"
```

## IDE Connection Issues

### VSCode Remote-SSH Issues

See [IDE Setup Guide](IDE_SETUP.md#common-troubleshooting) for general issues and [VSCode Setup Guide](VSCODE.md#vs-code-troubleshooting) for VS Code-specific troubleshooting.

Common quick fixes:

1. Clear VSCode's remote server cache:

   ```bash
   rm -rf ~/.vscode-server
   ```

2. Restart VSCode and reconnect

### IntelliJ Gateway Issues

See [IDE Setup Guide](IDE_SETUP.md#common-troubleshooting) for general issues and [IntelliJ Setup Guide](INTELLIJ.md#intellij-troubleshooting) for IntelliJ-specific troubleshooting.

Common quick fixes:

1. Clear Gateway cache
2. Verify SSH configuration in Gateway settings
3. Try connecting via terminal first to verify SSH works

## Performance Issues

### Slow SSH Connection

**Solutions:**

1. Add connection multiplexing to `~/.ssh/config`:

   ```bash
   Host my-claude-dev
       ControlMaster auto
       ControlPath ~/.ssh/control-%r@%h:%p
       ControlPersist 10m
   ```

2. Use a region closer to you:

   ```bash
   flyctl regions list
   ./scripts/vm-setup.sh --app-name my-claude --region <closer-region>
   ```

### VM Running Slowly

**Solutions:**

1. Check current resources:

   ```bash
   flyctl scale show -a my-claude-dev
   ```

2. Scale up if needed:

   ```bash
   flyctl scale vm shared-cpu-2x -a my-claude-dev
   flyctl scale memory 2048 -a my-claude-dev
   ```

3. Use performance CPU for intensive workloads:

   ```bash
   flyctl scale vm performance-2x -a my-claude-dev
   ```

## Cost and Billing Issues

### Unexpected Charges

**Problem:** Higher than expected Fly.io charges.

**Solutions:**

1. Monitor usage regularly:

   ```bash
   ./scripts/cost-monitor.sh
   ```

2. Ensure auto-suspend is working:

   ```bash
   flyctl status -a my-claude-dev
   # Should show "stopped" when not in use
   ```

3. Suspend VMs when not needed:

   ```bash
   ./scripts/vm-suspend.sh --app-name my-claude-dev
   ```

4. Review Fly.io dashboard:

   - Check at https://fly.io/dashboard
   - Look for running machines you forgot about

### Reducing Costs

1. **Use shared CPU instead of performance**:

   ```bash
   flyctl scale vm shared-cpu-1x -a my-claude-dev
   ```

2. **Reduce memory allocation**:

   ```bash
   flyctl scale memory 512 -a my-claude-dev
   ```

3. **Delete unused volumes**:

   ```bash
   flyctl volumes list -a my-claude-dev
   flyctl volumes destroy <volume-id> -a my-claude-dev
   ```

## Claude Tools Issues

### Claude Authentication Failed

**Problem:** Can't authenticate Claude Code.

**Solutions:**

1. Check if you have a valid subscription or API key

2. Re-run authentication:

   ```bash
   claude logout
   claude
   ```

3. For API key authentication:

   ```bash
   export ANTHROPIC_API_KEY="sk-ant-..."
   claude
   ```

### Claude Flow Init Fails

**Problem:** `npx claude-flow@alpha init` fails.

**Solutions:**

1. Ensure you're in a project directory:

   ```bash
   cd /workspace/projects/active/your-project
   ```

2. Clear npm cache and retry:

   ```bash
   npm cache clean --force
   npx claude-flow@alpha init --force
   ```

3. Check Node.js version:

   ```bash
   node --version  # Should be 18.x or later
   ```

## Getting More Help

If your issue isn't covered here:

1. **Check logs for detailed error messages**:

   ```bash
   flyctl logs -a my-claude-dev --since 1h
   ```

2. **Enable debug mode for scripts**:

   ```bash
   DEBUG=true ./scripts/vm-setup.sh --app-name my-claude-dev
   ```

3. **Community resources**:

   - [Fly.io Community Forum](https://community.fly.io)
   - [Claude Documentation](https://docs.anthropic.com)
   - [GitHub Issues](https://github.com/pacphi/claude-flow-on-fly/issues)

4. **Contact support**:

   - Fly.io: https://fly.io/docs/about/support/
   - Anthropic: https://support.anthropic.com

Remember to include:

- Exact error messages
- Commands you ran
- Output from `flyctl status` and `flyctl logs`
- Your `fly.toml` configuration (remove any secrets)
