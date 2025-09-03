# Command Reference

## VM Management Commands

### Initial Setup

**Deploy new VM:**

```bash
./scripts/vm-setup.sh --app-name <name> --region <region>

# Options:
--app-name <name>         # Fly.io application name (required)
--region <region>         # Deployment region (default: iad)
--cpu-kind <shared|performance>  # CPU type (default: shared)
--cpu-count <number>      # Number of CPUs (default: 1)
--memory <mb>             # Memory in MB (default: 1024)
--volume-size <gb>        # Storage size in GB (default: 30)

# Examples:
./scripts/vm-setup.sh --app-name dev-vm --region lax
./scripts/vm-setup.sh --app-name prod-vm --cpu-kind performance --cpu-count 2 --memory 4096
```

**Configure environment (first time):**

```bash
# On the VM after SSH connection
/workspace/scripts/vm-configure.sh

# Options:
--extensions-only         # Run only extension scripts
--skip-extensions         # Skip extension installation
--verbose                 # Show detailed output
--help                    # Show usage information
```

### VM Lifecycle

**Suspend VM (save costs):**

```bash
./scripts/vm-suspend.sh [app-name]

# If no app-name provided, uses current directory name
# Suspends all machines in the application
```

**Resume VM:**

```bash
./scripts/vm-resume.sh [app-name]

# Starts all suspended machines
# VM will also auto-resume on SSH connection
```

**Restart VM:**

```bash
flyctl machine restart <machine-id> -a <app-name>

# Get machine ID:
flyctl machine list -a <app-name>
```

**Completely remove VM and resources:**

```bash
./scripts/vm-teardown.sh --app-name <name>

# Options:
--app-name <name>        # Application to remove (required)
--backup                # Create backup before removal
--force                 # Skip confirmation prompts

# Examples:
./scripts/vm-teardown.sh --app-name old-dev --backup
./scripts/vm-teardown.sh --app-name test-env --force
```

### VM Status and Monitoring

**Check VM status:**

```bash
flyctl status -a <app-name>
flyctl machine list -a <app-name>
flyctl logs -a <app-name>
flyctl metrics -a <app-name>
```

**Resource monitoring:**

```bash
./scripts/cost-monitor.sh

# Options:
--action <status|history|export|budget|alert>
--export-format <csv|json> # For export action
--export-file <filename>   # Output file for export
--monthly-limit <amount>   # For budget action
--threshold <percentage>   # Alert threshold
--daily-email <email>      # For alert notifications
--notify <slack|email>     # Notification method

# Examples:
./scripts/cost-monitor.sh --action status
./scripts/cost-monitor.sh --action export --export-format csv --export-file usage.csv
./scripts/cost-monitor.sh --action budget --monthly-limit 50
```

## Data Management Commands

### Backup Operations

**Create backup:**

```bash
./scripts/volume-backup.sh

# Options:
--action <full|incremental|sync|analyze>
--project <name>           # Backup specific project
--destination <path>       # Backup destination
--compress                 # Compress backup files
--exclude-cache            # Skip cache directories

# Examples:
./scripts/volume-backup.sh --action full --compress
./scripts/volume-backup.sh --project my-app --destination /external/backup
./scripts/volume-backup.sh --action incremental --exclude-cache
```

**Restore from backup:**

```bash
./scripts/volume-restore.sh --file <backup-file>

# Options:
--file <path>              # Backup file to restore (required)
--destination <path>       # Restore destination (default: /workspace)
--partial                  # Allow partial restoration
--verify                   # Verify backup integrity before restore

# Examples:
./scripts/volume-restore.sh --file backup_20250104_120000.tar.gz
./scripts/volume-restore.sh --file backup.tar.gz --destination /workspace/restore --verify
```

### Volume Management

**List volumes:**
```bash
flyctl volumes list -a <app-name>
```

**Create additional volume:**

```bash
flyctl volumes create <name> --region <region> --size <gb> -a <app-name>

# Options:
--region <region>          # Volume region
--size <gb>                # Volume size in GB
--encrypted                # Enable encryption (if supported)
--snapshot-id <id>         # Create from snapshot
```

**Extend volume:**

```bash
flyctl volumes extend <volume-id> --size <gb> -a <app-name>
```

## Development Commands

### SSH Connection

**Connect to VM:**

```bash
ssh developer@<app-name>.fly.dev -p 10022

# With specific key:
ssh -i ~/.ssh/specific_key developer@<app-name>.fly.dev -p 10022

# Connection troubleshooting:
ssh -vvv developer@<app-name>.fly.dev -p 10022
```

**SSH key management:**

```bash
# Add new SSH key
flyctl ssh issue --agent --email user@example.com -a <app-name>

# Console access (emergency)
flyctl ssh console -a <app-name>
```

### Project Management

**Create new project:**

```bash
# On the VM
/workspace/scripts/lib/new-project.sh <project-name> [options]

# Options:
--type <node|python|go|rust|web>  # Project type
--git-name "<name>"               # Git user name
--git-email "<email>"             # Git user email
--github-repo                     # Create GitHub repository
--claude-init                     # Initialize Claude Flow

# Examples:
/workspace/scripts/lib/new-project.sh my-api --type node --github-repo
/workspace/scripts/lib/new-project.sh data-analysis --type python --claude-init
```

**Clone and enhance existing project:**

```bash
clone-project <repository-url> [options]

# Options:
--fork                    # Fork repository before cloning
--branch <name>           # Clone specific branch
--feature <name>          # Create feature branch after clone
--git-name "<name>"       # Configure git user name
--git-email "<email>"     # Configure git user email
--no-enhance              # Skip Claude enhancements

# Examples:
clone-project https://github.com/user/repo --fork --feature my-changes
clone-project https://github.com/company/app --branch develop --git-name "John" --git-email "john@company.com"
```

### AI Development Tools

**Claude Code:**

```bash
# Start Claude Code session
claude

# Authenticate (first time)
claude auth

# Check version and status
claude --version
claude --help
```

**Claude Flow:**

```bash
# Initialize Claude Flow in project
cd /workspace/projects/active/my-project
npx claude-flow@alpha init --force

# Start swarm development
npx claude-flow@alpha swarm "implement user authentication"

# Swarm management
npx claude-flow@alpha swarm list          # List active swarms
npx claude-flow@alpha swarm status        # Check swarm status
npx claude-flow@alpha swarm stop          # Stop current swarm

# Agent management
npx claude-flow@alpha agent list          # List available agents
npx claude-flow@alpha agent run <name>    # Run specific agent
```

## Configuration Commands

### Environment Configuration

**System status:**

```bash
# On the VM
/workspace/scripts/lib/system-status.sh

# Check specific components
/workspace/scripts/lib/validate-setup.sh
```

**Git configuration:**

```bash
# Global git setup
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Project-specific git
cd /workspace/projects/active/project-name
git config user.name "Project Name"
git config user.email "project@company.com"
```

**Environment variables:**

```bash
# Set secrets via Fly.io
flyctl secrets set API_KEY=value -a <app-name>
flyctl secrets set DATABASE_URL="postgresql://..." -a <app-name>

# List current secrets
flyctl secrets list -a <app-name>

# Remove secret
flyctl secrets unset API_KEY -a <app-name>
```

### Extension Management

**List available extensions:**

```bash
ls /workspace/scripts/extensions.d/*.example
```

**Enable extension:**

```bash
# Copy example to enable
cp /workspace/scripts/extensions.d/10-rust.sh.example \
   /workspace/scripts/extensions.d/10-rust.sh

# Run specific extension
/workspace/scripts/extensions.d/10-rust.sh
```

**Create custom extension:**

```bash
# Create new extension
cat > /workspace/scripts/extensions.d/50-custom.sh << 'EOF'
#!/bin/bash
source /workspace/scripts/lib/common.sh

print_status "Installing custom tools..."
# Your installation commands
print_success "Custom tools ready"
EOF

chmod +x /workspace/scripts/extensions.d/50-custom.sh
```

## Networking Commands

### Domain and SSL

**Add custom domain:**

```bash
flyctl certs create your-domain.com -a <app-name>

# Check certificate status
flyctl certs show your-domain.com -a <app-name>

# List all certificates
flyctl certs list -a <app-name>
```

**Remove domain:**

```bash
flyctl certs delete your-domain.com -a <app-name>
```

### Database Integration

**PostgreSQL:**

```bash
# Create PostgreSQL cluster
flyctl postgres create --name <db-name> --region <region>

# Attach to application
flyctl postgres attach <db-name> -a <app-name>

# Connect to database
flyctl postgres connect -a <db-name>

# Database proxy (for external access)
flyctl proxy 5432 -a <db-name>
```

**Redis:**

```bash
# Create Redis instance
flyctl redis create --name <cache-name> --region <region>

# Attach to application
flyctl redis attach <cache-name> -a <app-name>

# Connect to Redis
redis-cli -u $REDIS_URL
```

## Troubleshooting Commands

### Common Issues

**VM won't start:**

```bash
# Check application status
flyctl status -a <app-name>

# Check machine status
flyctl machine list -a <app-name>

# Restart machine
flyctl machine restart <machine-id> -a <app-name>

# View logs
flyctl logs -a <app-name>
```

**SSH connection issues:**

```bash
# Test connection with verbose output
ssh -vvv developer@<app-name>.fly.dev -p 10022

# Check SSH service on VM
flyctl ssh console -a <app-name> "systemctl status ssh"

# Restart SSH service
flyctl ssh console -a <app-name> "sudo systemctl restart ssh"
```

**Storage issues:**

```bash
# Check disk usage
flyctl ssh console -a <app-name> "df -h"

# Check volume status
flyctl volumes list -a <app-name>

# Clean up workspace
flyctl ssh console -a <app-name> "/workspace/scripts/lib/cleanup.sh"
```

### Log Analysis

**View logs:**

```bash
# Real-time logs
flyctl logs -a <app-name>

# Historical logs
flyctl logs -a <app-name> --since 1h

# Specific instance logs
flyctl logs -a <app-name> --instance <instance-id>
```

**System logs on VM:**

```bash
# SSH into VM first
ssh developer@<app-name>.fly.dev -p 10022

# System logs
sudo journalctl -u ssh
sudo journalctl -f
tail -f /var/log/syslog

# Authentication logs
sudo tail -f /var/log/auth.log
```

## File Paths and Locations

### Important Directories

**On VM (Runtime):**

```
/workspace/                     # Persistent volume root
├── developer/                  # User home directory
├── projects/                   # Development projects
│   ├── active/                 # Current projects
│   └── archive/                # Archived projects
├── scripts/                    # Management scripts
│   ├── lib/                    # Shared libraries
│   └── extensions.d/           # Extension scripts
├── config/                     # Configuration files
├── backups/                    # Local backups
└── .config/                    # Application configs
```

**Repository Structure:**

```
claude-flow-on-fly/
├── README.md                  # Main documentation
├── CLAUDE.md                  # Claude context
├── Dockerfile                 # Container definition
├── fly.toml                   # Fly.io configuration
├── docker/                    # Container files
├── scripts/                   # Local management scripts
├── templates/                 # Configuration templates
└── docs/                      # Documentation
```

### Configuration Files

**Key Configuration Files:**

- `/workspace/developer/.bashrc` - Shell configuration
- `/workspace/developer/.gitconfig` - Git configuration
- `/workspace/developer/.claude/settings.json` - Claude Code settings
- `/workspace/.swarm/` - Claude Flow configuration
- `/etc/ssh/sshd_config` - SSH daemon configuration
- `fly.toml` - Fly.io deployment configuration

### Environment Variables

**Available Environment Variables:**

- `DATABASE_URL` - PostgreSQL connection string (if attached)
- `REDIS_URL` - Redis connection string (if attached)
- `ANTHROPIC_API_KEY` - Claude API key
- `GITHUB_TOKEN` - GitHub authentication token
- `GIT_USER_NAME` - Git user name
- `GIT_USER_EMAIL` - Git user email

## Performance and Scaling

### Resource Scaling

**Scale CPU and Memory:**

```bash
flyctl scale memory 2048 -a <app-name>      # Scale memory to 2GB
flyctl scale count 2 -a <app-name>          # Scale to 2 instances

# Scale specific machine
flyctl machine update <machine-id> --vm-size shared-cpu-2x -a <app-name>
```

**Auto-scaling configuration:**

```bash
# Edit fly.toml for auto-scaling rules
[services.auto_stop_machines]
  enabled = true
  min_machines_running = 0

[services.auto_start_machines]
  enabled = true
```

This comprehensive command reference provides all the essential commands for managing your AI-assisted remote development environment effectively.
