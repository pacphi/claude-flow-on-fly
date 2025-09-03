# Cost Management

## Cost Structure

Understanding Fly.io's billing model helps optimize your development environment costs.

### Billing Components

**Compute Resources**

- **Per-second billing** when VM is running
- **Scale-to-zero**: No compute charges when suspended
- **CPU Types**: Shared (cheaper) vs Performance (dedicated)
- **Memory**: Billed per GB allocated

**Storage**

- **Persistent Volumes**: Monthly charge regardless of VM state
- **Snapshots**: Additional charge for backup retention
- **Network**: Egress charges for data transfer

## Cost Estimates

### Configuration Examples

**Minimal Development** (1x shared-cpu, 256MB RAM, 10GB storage)

- VM running 10% time: ~$1.70/month
- VM running 25% time: ~$2.50/month
- VM running 50% time: ~$4.50/month

**Standard Development** (1x shared-cpu, 4GB RAM, 20GB storage)

- VM running 10% time: ~$4.25/month
- VM running 25% time: ~$7.75/month
- VM running 50% time: ~$14.25/month

**Heavy Development** (2x shared-cpu, 8GB RAM, 30GB storage)

- VM running 25% time: ~$16.20/month
- VM running 50% time: ~$30.90/month
- VM running 100% time: ~$60.30/month

**Performance Workloads** (4x performance-cpu, 16GB RAM, 50GB storage)

- VM running 25% time: ~$48.50/month
- VM running 50% time: ~$95.50/month
- VM running 100% time: ~$189.00/month

*Estimates include compute + storage + egress. Actual costs may vary based on usage patterns and region.*

## Automatic Cost Optimization

### Auto-suspend Configuration

The VM automatically suspends when idle to minimize costs:

```toml
# fly.toml configuration
[services.auto_stop_machines]
enabled = true

[services.auto_start_machines]
enabled = true
```

**Idle Detection**

- SSH connection monitoring
- HTTP request detection
- Configurable timeout periods
- Graceful shutdown process

**Resume Triggers**

- SSH connection attempts
- HTTP requests
- Fly.io wake-up calls
- Scheduled tasks

### Scale-to-Zero Benefits

- **Zero compute costs** when not developing
- **Persistent data** remains available
- **Instant resume** on connection
- **No manual intervention** required

## Manual Cost Control

### VM Lifecycle Management

**Suspend VM manually:**

```bash
./scripts/vm-suspend.sh
# Stops the VM immediately to save costs
```

**Resume VM:**

```bash
./scripts/vm-resume.sh
# Starts the VM when you're ready to develop
```

**Check VM status:**

```bash
flyctl status -a my-claude-dev
flyctl machine list -a my-claude-dev
```

### Resource Optimization

**Scale down for light work:**

```bash
flyctl scale memory 256 -a my-claude-dev
flyctl scale count 1 -a my-claude-dev
```

**Scale up for intensive tasks:**

```bash
flyctl scale memory 8192 -a my-claude-dev
flyctl scale count 2 -a my-claude-dev
```

**Monitor resource usage:**

```bash
flyctl metrics -a my-claude-dev
```

## Cost Monitoring

### Usage Tracking Script

The built-in cost monitoring script provides detailed usage analytics:

```bash
# Check current status and estimated costs
./scripts/cost-monitor.sh --action status

# View historical usage patterns
./scripts/cost-monitor.sh --action history

# Export usage data for analysis
./scripts/cost-monitor.sh --action export --export-format csv --export-file usage.csv
```

**Monitoring Features:**

- Real-time cost estimates
- Usage pattern analysis
- Resource utilization metrics
- Cost trend projections
- Budget alerts and warnings

### Fly.io Dashboard

- **Usage Metrics**: CPU, memory, and network utilization
- **Billing History**: Detailed cost breakdown
- **Resource Allocation**: Current and historical configurations
- **Budget Alerts**: Set spending limits and notifications

## Storage Cost Optimization

### Volume Management

**Monitor storage usage:**

```bash
# On the VM
df -h /workspace
du -sh /workspace/*

# From local machine
./scripts/volume-backup.sh --action analyze
```

**Clean up unnecessary files:**

```bash
# On the VM
/workspace/scripts/lib/cleanup.sh

# Remove old caches
rm -rf /workspace/developer/.cache/npm
rm -rf /workspace/developer/.cache/pip
```

**Archive old projects:**

```bash
# Move to archive directory
mv /workspace/projects/active/old-project /workspace/projects/archive/

# Or create backup and remove
./scripts/volume-backup.sh --project old-project
rm -rf /workspace/projects/active/old-project
```

### Backup Strategy

**Efficient backup schedule:**

- **Daily**: Critical project files only
- **Weekly**: Full workspace backup
- **Monthly**: Archive and compress old backups

```bash
# Incremental backup (faster, cheaper)
./scripts/volume-backup.sh --action incremental

# Full backup (thorough, more expensive)
./scripts/volume-backup.sh --action full

# Compressed archive
./scripts/volume-backup.sh --action archive --compress
```

## Team Cost Management

### Shared VM Strategy

Multiple developers sharing one VM:

**Benefits:**

- Split costs among team members
- Shared development environment
- Centralized tool management

**Considerations:**

- Resource contention during peak usage
- Coordination for major updates
- Security and access management

### Individual VM Strategy

Separate VMs for each developer:

**Benefits:**

- Isolated development environments
- Independent resource scaling
- Personal customization freedom

**Cost Optimization:**

- Standardized VM configurations
- Shared backup storage
- Team-wide monitoring dashboard

## Advanced Cost Strategies

### Multi-region Deployment

Deploy VMs in cost-effective regions:

```bash
# List regions and pricing
flyctl platform regions

# Deploy in cheaper regions
./scripts/vm-setup.sh --region lax  # Los Angeles
./scripts/vm-setup.sh --region ord  # Chicago
```

### Scheduled Scaling

Automatically scale based on development schedules:

```bash
# Scale up during work hours (9 AM)
echo "0 9 * * 1-5 /usr/local/bin/flyctl scale memory 2048 -a my-claude-dev" | crontab

# Scale down after hours (6 PM)
echo "0 18 * * 1-5 /usr/local/bin/flyctl scale memory 256 -a my-claude-dev" | crontab
```

### Resource Right-sizing

Monitor and optimize resource allocation:

1. **Baseline Monitoring**: Track usage for 1-2 weeks
2. **Identify Patterns**: Find peak and minimum resource needs
3. **Optimize Configuration**: Right-size CPU and memory
4. **Continuous Monitoring**: Adjust based on workload changes

## Budget Planning

### Monthly Budget Calculation

**Fixed Costs:**

- Persistent volume: `$volume_size_gb * $0.15`
- Snapshots: `$snapshot_count * $0.02`

**Variable Costs:**

- Compute: `$hourly_rate * $hours_running * $days_per_month`
- Egress: `$gb_transferred * $0.02`

**Budget Planning Tool:**

```bash
./scripts/cost-monitor.sh --action budget --monthly-limit 50
# Sets alerts when approaching $50/month spending
```

### Cost Alerts

Set up notifications for cost management:

```bash
# Daily cost summary
./scripts/cost-monitor.sh --action alert --daily-email user@example.com

# Budget threshold alerts
./scripts/cost-monitor.sh --action budget --threshold 80 --notify slack
```

## Cost Troubleshooting

### Unexpected High Costs

**Common Causes:**

- VM not suspending (check auto-suspend configuration)
- High network egress (large file transfers)
- Resource over-allocation (too much CPU/memory)
- Multiple VMs running simultaneously

**Investigation Steps:**

1. Check VM status: `flyctl machine list -a my-claude-dev`
2. Review resource usage: `flyctl metrics -a my-claude-dev`
3. Analyze billing: Fly.io dashboard billing section
4. Monitor traffic: Check egress patterns

**Quick Fixes:**

```bash
# Force suspend all machines
flyctl machine stop --all -a my-claude-dev

# Reset to minimal configuration
flyctl scale memory 256 -a my-claude-dev
flyctl scale count 1 -a my-claude-dev

# Check for resource leaks
./scripts/cost-monitor.sh --action audit
```

By following these cost management strategies, you can maintain a powerful AI-assisted development environment while keeping expenses predictable and optimized.
