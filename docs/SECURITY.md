# Security

## Security Architecture

This remote development environment implements multiple layers of security to protect your code, data, and infrastructure.

## Network Security

### SSH-Only Access

- **Port Configuration**: Non-standard port 10022 to reduce attack surface
- **Key-Based Authentication**: Public key authentication only, passwords disabled
- **Root Access**: Root login completely disabled
- **Connection Limits**: Configurable connection rate limiting

### Fly.io Network Protection

- **Private Networking**: VMs isolated in Fly.io private network
- **DDoS Protection**: Built-in protection against distributed attacks
- **Regional Isolation**: Deploy in specific regions for compliance
- **Firewall Rules**: Only SSH port exposed externally

### Network Configuration

**SSH Hardening (`/etc/ssh/sshd_config`):**

```bash
# Authentication
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
AuthenticationMethods publickey

# Network
Port 2222                    # Internal SSH daemon port (avoids Fly.io hallpass conflicts)
Protocol 2                   # External access via port 10022 -> internal port 2222
AllowUsers developer         # Fly.io also provides hallpass service on port 22 for flyctl ssh console

# Security
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 5

# Logging
SyslogFacility AUTH
LogLevel INFO
```

**Firewall Rules:**

```bash
# UFW configuration (Ubuntu Firewall)
ufw default deny incoming
ufw default allow outgoing
ufw allow 10022/tcp comment 'SSH'
ufw --force enable

# Check firewall status
ufw status verbose
```

## Authentication and Authorization

### SSH Key Management

**Adding Team Members:**

```bash
# Generate SSH key pair (on developer machine)
ssh-keygen -t ed25519 -C "developer@company.com"

# Add to authorized_keys (on VM)
cat ~/.ssh/id_ed25519.pub >> /workspace/developer/.ssh/authorized_keys

# Or use Fly.io CLI
flyctl ssh issue --agent --email developer@company.com -a my-sindri-dev
```

**Key Rotation:**

```bash
# Regular key rotation (every 90 days)
ssh-keygen -t ed25519 -C "developer@company.com-$(date +%Y%m%d)"

# Update authorized_keys
sed -i '/old-key-identifier/d' /workspace/developer/.ssh/authorized_keys
cat ~/.ssh/new_key.pub >> /workspace/developer/.ssh/authorized_keys

# Test new key
ssh -i ~/.ssh/new_key developer@my-sindri-dev.fly.dev -p 10022
```

### User Access Control

**Sudo Configuration:**

```bash
# /etc/sudoers.d/developer
developer ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/systemctl, /usr/local/bin/docker
developer ALL=(ALL) PASSWD: /bin/su, /usr/bin/passwd

# Restricted commands that require password
Cmnd_Alias RESTRICTED = /bin/su *, /usr/bin/passwd *
developer ALL=(ALL) RESTRICTED
```

**File Permissions:**

```bash
# Secure workspace permissions
chmod 700 /workspace/developer
chmod 600 /workspace/developer/.ssh/authorized_keys
chmod 700 /workspace/developer/.ssh

# Project permissions
find /workspace/projects -type d -exec chmod 755 {} \;
find /workspace/projects -type f -exec chmod 644 {} \;
```

## Secret Management

### Fly.io Secrets

**Setting Secrets:**

```bash
# API keys and tokens
flyctl secrets set ANTHROPIC_API_KEY=sk-ant-... -a my-sindri-dev
flyctl secrets set GITHUB_TOKEN=ghp_... -a my-sindri-dev
flyctl secrets set OPENAI_API_KEY=sk-... -a my-sindri-dev
flyctl secrets set PERPLEXITY_API_KEY=pplx-... -a my-sindri-dev

# Database credentials
flyctl secrets set DATABASE_PASSWORD=secure_password -a my-sindri-dev
flyctl secrets set REDIS_PASSWORD=redis_secret -a my-sindri-dev

# Custom application secrets
flyctl secrets set JWT_SECRET=$(openssl rand -hex 32) -a my-sindri-dev
flyctl secrets set ENCRYPTION_KEY=$(openssl rand -hex 32) -a my-sindri-dev
```

**Accessing Secrets Securely:**

```bash
# In scripts, never echo secrets
API_KEY=${ANTHROPIC_API_KEY:-"not_set"}
if [ "$API_KEY" = "not_set" ]; then
    echo "ERROR: ANTHROPIC_API_KEY not configured"
    exit 1
fi

# Use secrets in applications
curl -H "Authorization: Bearer $ANTHROPIC_API_KEY" https://api.anthropic.com/
```

### Local Secret Storage

**Git Secrets Prevention:**

```bash
# Install git-secrets
apt update && apt install git-secrets

# Configure globally
git secrets --register-aws --global
git secrets --install ~/.git-templates/git-secrets
git config --global init.templateDir ~/.git-templates/git-secrets

# Add custom patterns
git secrets --add --global 'sk-[a-zA-Z0-9]{48}'  # Anthropic keys
git secrets --add --global 'ghp_[a-zA-Z0-9]{36}' # GitHub tokens
git secrets --add --global 'xoxb-[a-zA-Z0-9-]+'  # Slack tokens
git secrets --add --global 'pplx-[a-zA-Z0-9]+'   # Perplexity API keys

# Scan existing repositories
git secrets --scan
```

**Environment File Security:**

```bash
# Secure .env files
chmod 600 /workspace/projects/*/.env
echo ".env" >> /workspace/projects/*/.gitignore

# Template for .env files
cat > /workspace/templates/.env.example << 'EOF'
# Copy to .env and fill in actual values
DATABASE_URL=postgresql://localhost:5432/dbname
REDIS_URL=redis://localhost:6379
API_KEY=your_api_key_here
EOF
```

## Data Protection

### Encryption

**Volume Encryption:**

```bash
# Create encrypted volume (if supported in region)
flyctl volumes create encrypted_workspace \
    --region sjc \
    --size 50 \
    --encrypted

# Verify encryption status
flyctl volumes list -a my-sindri-dev
```

**File-Level Encryption:**

```bash
# Encrypt sensitive files with gpg
gpg --symmetric --cipher-algo AES256 sensitive_file.txt

# Decrypt when needed
gpg --decrypt sensitive_file.txt.gpg > sensitive_file.txt

# Secure deletion
shred -vfz -n 3 sensitive_file.txt
```

### Backup Security

**Encrypted Backups:**

```bash
# Create encrypted backup
tar czf - /workspace/projects | \
    gpg --symmetric --cipher-algo AES256 \
    --output backup_$(date +%Y%m%d).tar.gz.gpg

# Restore encrypted backup
gpg --decrypt backup_20250104.tar.gz.gpg | \
    tar xzf - -C /workspace/restore/
```

**Backup Access Control:**

```bash
# Secure backup storage permissions
chmod 600 /workspace/backups/*.tar.gz.gpg
chown developer:developer /workspace/backups/*

# Remote backup with authentication
# Note: -p 2222 is for the external backup server's SSH port, not the Fly.io VM
# For Fly.io VM SSH access, use -p 10022 (external) or flyctl ssh console
rsync -avz --delete \
    -e "ssh -i ~/.ssh/backup_key -p 2222" \
    /workspace/backups/ \
    backup-server:/secure-backups/claude-dev/
```

## Application Security

### Code Security

**Static Analysis:**

```bash
# Install security scanning tools
npm install -g @npmjs/arborist
npm install -g audit-ci
pip install bandit safety

# Scan dependencies
npm audit --audit-level moderate
pip-audit --desc
safety check

# Code security scan
bandit -r /workspace/projects/active/ -f json
```

**Git Hooks for Security:**

```bash
# Pre-commit security checks
cat > /workspace/projects/active/.git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Security checks before commit

# Check for secrets
git secrets --scan

# Dependency audit
npm audit --audit-level high
pip-audit --exit-code

# Static analysis
bandit -r . -ll
EOF

chmod +x /workspace/projects/active/.git/hooks/pre-commit
```

### Claude Code Security

**API Key Security:**

```bash
# Store Claude API key securely
flyctl secrets set ANTHROPIC_API_KEY=sk-ant-... -a my-sindri-dev

# Never log API keys
export ANTHROPIC_API_KEY
claude --version  # Test without exposing key

# Audit API key usage
grep -r "ANTHROPIC_API_KEY" /workspace/projects/ || echo "No API keys in code"
```

**Claude Flow Security:**

```yaml
# Secure swarm configuration
# /workspace/.swarm/security.yaml
security:
  api_keys:
    storage: environment_variables
    rotation_days: 90
    audit_log: true

  network:
    allow_external_apis: false
    whitelist_domains:
      - "api.anthropic.com"
      - "api.github.com"

  data:
    memory_encryption: true
    log_retention_days: 30
    pii_detection: true
```

## Monitoring and Auditing

### Security Monitoring

**Access Logging:**

```bash
# SSH access monitoring
tail -f /var/log/auth.log | grep ssh

# Login monitoring script
cat > /workspace/scripts/monitor-access.sh << 'EOF'
#!/bin/bash
# Monitor and alert on access patterns

LOG_FILE="/var/log/auth.log"
ALERT_EMAIL="admin@company.com"

# Monitor failed login attempts
FAILED_ATTEMPTS=$(grep "Failed password" $LOG_FILE | tail -10 | wc -l)
if [ $FAILED_ATTEMPTS -gt 5 ]; then
    echo "WARNING: $FAILED_ATTEMPTS failed login attempts" | \
        mail -s "Security Alert: Failed Logins" $ALERT_EMAIL
fi

# Monitor successful logins
grep "Accepted publickey" $LOG_FILE | tail -5
EOF

# Run monitoring every hour
echo "0 * * * * /workspace/scripts/monitor-access.sh" | crontab -
```

**System Integrity Monitoring:**

```bash
# File integrity monitoring with AIDE
apt install aide
aide --init
cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Daily integrity check
echo "0 2 * * * aide --check" | crontab -

# Custom integrity check
cat > /workspace/scripts/integrity-check.sh << 'EOF'
#!/bin/bash
# Check critical file integrity

CRITICAL_FILES=(
    "/etc/ssh/sshd_config"
    "/etc/sudoers"
    "/workspace/scripts/vm-configure.sh"
)

for file in "${CRITICAL_FILES[@]}"; do
    if [ -f "$file" ]; then
        sha256sum "$file"
    fi
done
EOF
```

### Audit Logging

**Comprehensive Audit Trail:**

```bash
# Install auditd for system call auditing
apt install auditd

# Configure audit rules
cat > /etc/audit/rules.d/custom.rules << 'EOF'
# Monitor authentication
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k privilege_escalation

# Monitor SSH configuration
-w /etc/ssh/sshd_config -p wa -k ssh_config

# Monitor sensitive directories
-w /workspace/projects/ -p wa -k code_changes
-w /workspace/scripts/ -p wa -k script_changes

# Monitor network connections
-a always,exit -F arch=b64 -S connect -k network_connect
EOF

# Restart auditd
systemctl restart auditd

# Search audit logs
ausearch -k ssh_config
ausearch -k code_changes --start today
```

## Incident Response

### Security Incident Procedures

**Immediate Response:**

```bash
# Incident response script
cat > /workspace/scripts/security-incident.sh << 'EOF'
#!/bin/bash
# Emergency security response

echo "SECURITY INCIDENT RESPONSE ACTIVATED"
echo "Timestamp: $(date)"

# 1. Preserve evidence
cp -r /var/log/ /workspace/incident-logs-$(date +%Y%m%d-%H%M%S)/

# 2. Check current connections
ss -tuln
who -u

# 3. Lock down system
# Disable SSH (use with extreme caution)
# systemctl stop ssh

# 4. Alert team
echo "Security incident detected on $(hostname)" | \
    mail -s "URGENT: Security Incident" security@company.com

# 5. Capture system state
ps aux > /workspace/incident-processes.txt
netstat -anlp > /workspace/incident-network.txt
df -h > /workspace/incident-disk.txt

echo "Incident response complete. Review /workspace/incident-* files"
EOF

chmod +x /workspace/scripts/security-incident.sh
```

**Recovery Procedures:**

```bash
# System recovery checklist
cat > /workspace/docs/security-recovery.md << 'EOF'
# Security Incident Recovery

## Immediate Steps
1. Isolate affected systems
2. Preserve evidence
3. Assess damage scope
4. Notify stakeholders

## Investigation
1. Review audit logs: `ausearch --start recent`
2. Check access logs: `grep -i "authentication failure" /var/log/auth.log`
3. Analyze network connections
4. Review file integrity reports

## Recovery
1. Patch vulnerabilities
2. Rotate all credentials
3. Update security configurations
4. Restore from clean backups if necessary

## Prevention
1. Update security monitoring
2. Enhance access controls
3. Conduct security training
4. Review incident response procedures
EOF
```

By implementing these security measures, your remote development environment maintains strong protection against
common threats while providing the flexibility needed for productive AI-assisted development.
