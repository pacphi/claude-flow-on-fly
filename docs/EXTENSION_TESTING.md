# Extension System Testing

This document describes the comprehensive testing system for VM extensions.

## Overview

The extension testing workflow (`extension-tests.yml`) provides automated validation and functional testing
for all extensions in the `docker/lib/extensions.d/` directory. This ensures that users can confidently
activate and use any extension without encountering issues.

## Test Coverage

### 1. Extension Manager Validation

Tests the core extension management system:

- **Script Syntax**: Validates `extension-manager.sh` with shellcheck
- **List Command**: Verifies extension listing functionality
- **Name Extraction**: Tests extraction of extension names from filenames
- **Protected Extensions**: Verifies 00-init.sh cannot be deactivated
- **Backup Functionality**: Tests file backup creation

**When It Runs**: On every push/PR affecting extension files

### 2. Extension Syntax Validation

Validates all extension scripts for code quality:

- **Shellcheck Analysis**: Static analysis of all `.sh` and `.sh.example` files
- **Common.sh Sourcing**: Verifies proper utility function imports
- **Shebang Verification**: Ensures all scripts have `#!/bin/bash`
- **Error Handling**: Checks for use of print functions and error handling
- **Best Practices**: Validates adherence to extension development guidelines

**When It Runs**: On every push/PR affecting extension files

### 3. Core Extension Tests

Validates the protected 00-init.sh extension:

- **Deployment**: Deploys test VM with core extension
- **Component Verification**: Tests all core components:
  - Turbo Flow (Playwright, TypeScript, monitoring)
  - Agent Manager (binary, configuration)
  - Tmux Workspace (installation, configuration)
  - Context Management (loader scripts)
- **Protection**: Verifies core extension cannot be deactivated
- **Directory Structure**: Validates workspace layout

**When It Runs**: On push/PR (unless specific extension requested)

### 4. Per-Extension Tests (Matrix)

Comprehensive testing for each extension individually:

#### Tested Extensions

| Extension | Key Tools | Test Focus |
|-----------|-----------|------------|
| rust | rustc, cargo | Compilation, cargo tools |
| golang | go | Compilation, go modules |
| python | python3, pip3 | Execution, package management |
| docker | docker, docker-compose | Docker daemon, compose |
| jvm | java, sdk | SDKMAN, Java toolchain |
| php | php, composer | PHP execution, Symfony |
| ruby | ruby, gem, bundle | Ruby execution, Rails |
| dotnet | dotnet | .NET SDK, ASP.NET |
| infra-tools | terraform, ansible | IaC tools |
| cloud-tools | aws | Cloud provider CLIs |
| ai-tools | ollama, fabric | AI coding assistants |

#### Test Steps

For each extension:

1. **Activation**: Activate extension via extension-manager
2. **Installation**: Run `vm-configure.sh --extensions-only`
3. **Command Availability**: Verify all expected commands in PATH
4. **Key Functionality**: Test core capability (compilation, execution, etc.)
5. **Idempotency**: Run installation again to verify safe re-execution
6. **Resource Cleanup**: Destroy test VM and volumes

**When It Runs**:

- On push/PR affecting extension files
- On workflow dispatch (all or specific extension)

### 5. Extension Combinations

Tests common extension combinations for conflicts:

#### Test Combinations

- **fullstack**: Python + Docker + Cloud Tools
- **systems**: Rust + Go + Docker
- **enterprise**: JVM + Docker + Infrastructure Tools
- **ai-dev**: Python + AI Tools + Docker

#### Validation

- All extensions activate successfully
- No installation conflicts
- Cross-extension functionality works
- Tools from different extensions coexist

**When It Runs**:

- Manual workflow dispatch

### 6. Results Reporting

Generates comprehensive test report summary:

- Job status for all test categories
- Success/failure indicators
- Links to detailed logs
- GitHub Actions summary

## Workflow Triggers

### Automatic Triggers

```yaml
# On push to main/develop affecting extensions
push:
  branches: [ main, develop ]
  paths:
    - 'docker/lib/extensions.d/**'
    - 'docker/lib/extension-manager.sh'
    - 'docker/lib/common.sh'

# On pull requests
pull_request:
  branches: [ main, develop ]
  paths: [same as above]
```

### Manual Triggers

```bash
# Test specific extension
gh workflow run extension-tests.yml \
  -f extension_name=rust \
  -f skip_cleanup=false

# Test all extensions with cleanup disabled (for debugging)
gh workflow run extension-tests.yml \
  -f skip_cleanup=true
```

## Resource Requirements

### VM Specifications

Different test jobs use different VM sizes:

| Test Type | Memory | CPUs | Disk | Timeout |
|-----------|--------|------|------|---------|
| Core Extension | 2GB | 1 | 5GB | 45 min |
| Per-Extension | 4GB | 2 | 10GB | 60 min |
| Combinations | 8GB | 4 | 15GB | 90 min |

### Cost Considerations

- Each VM deployment costs according to Fly.io pricing
- Tests run in CI_MODE (SSH daemon disabled) for faster deployment
- Automatic cleanup prevents lingering resources
- Use `skip_cleanup=true` only for debugging

## Test Environments

All tests use:

- **CI_MODE**: Enabled to prevent SSH port conflicts
- **Fly.io Region**: `iad` (US East)
- **Deployment Strategy**: `immediate` (skip health checks)
- **Volume Encryption**: Disabled for faster setup

## Interpreting Results

### Success Criteria

A test passes when:

- ✅ Extension activates without errors
- ✅ `vm-configure.sh` completes successfully
- ✅ All expected commands are available
- ✅ Key functionality tests pass
- ✅ Idempotency check succeeds

### Common Failures

| Failure Type | Likely Cause | Resolution |
|--------------|--------------|------------|
| Activation failed | Missing .example file | Check file exists and naming |
| Configuration timeout | Extension takes too long | Increase timeout in matrix |
| Command not found | Installation incomplete | Check installation steps in extension |
| Idempotency failure | No existence check | Add `command_exists` checks |
| Conflict detected | Duplicate installations | Review extension interactions |

### Debugging Failed Tests

1. **Check Workflow Logs**: Detailed output for each step
2. **Review VM Logs**: `flyctl logs -a <app-name>`
3. **Run with Skip Cleanup**: Keep VM alive for inspection
4. **Test Locally**: Activate extension on local test VM
5. **Enable Debug Mode**: Set `DEBUG=true` in extension script

## Adding New Extensions

When adding a new extension, ensure it will pass tests:

### 1. Create Extension File

```bash
# Create example file
vim docker/lib/extensions.d/90-newlang.sh.example

# Follow template:
#!/bin/bash
# 90-newlang.sh.example - Install NewLang

source /workspace/scripts/lib/common.sh

if command_exists newlang; then
    print_warning "NewLang already installed"
    return 0
fi

print_status "Installing NewLang..."
# Installation steps...
print_success "NewLang installed"
```

### 2. Add to Test Matrix

Update `.github/workflows/extension-tests.yml`:

```yaml
matrix:
  extension:
    # ... existing extensions ...
    - { name: 'newlang', commands: 'newlang,newlang-cli',
        key_tool: 'newlang', timeout: '20m' }
```

### 3. Add Functionality Test

In the workflow, add test case:

```yaml
case "$key_tool" in
  # ... existing cases ...
  newlang)
    echo "Testing NewLang..."
    newlang --version
    newlang-cli test-command
    ;;
esac
```

### 4. Test Locally First

```bash
# On test VM
cd /workspace/scripts/lib
bash extension-manager.sh activate newlang
/workspace/scripts/vm-configure.sh --extensions-only
```

### 5. Verify Passes All Checks

- [ ] Shellcheck validation passes
- [ ] Common.sh properly sourced
- [ ] Idempotent (safe to run multiple times)
- [ ] Commands available after installation
- [ ] Timeout appropriate for installation time
- [ ] Cleanup doesn't leave artifacts

## Best Practices

### For Extension Developers

1. **Always Check Existence**: Use `command_exists` before installing
2. **Handle Errors Gracefully**: Don't exit on minor failures
3. **Use Print Functions**: `print_status`, `print_success`, `print_error`
4. **Test Idempotency**: Extension should be safe to run multiple times
5. **Document Dependencies**: Note any required extensions
6. **Set Reasonable Timeouts**: Consider installation time

### For Extension Users

1. **Review Test Results**: Check workflow before activating new extensions
2. **Test Individually**: Activate one extension at a time initially
3. **Check Combinations**: Review combination tests for your stack
4. **Monitor Resources**: Extensions increase VM resource usage
5. **Validate Installation**: Run validation scripts after activation

## Continuous Improvement

The extension testing system continuously evolves:

### Metrics Tracked

- Test execution time per extension
- Success/failure rates
- Resource usage patterns
- Common failure modes

### Planned Enhancements

- [ ] Performance benchmarking for extensions
- [ ] Cross-platform testing (different VM sizes)
- [ ] Dependency graph validation
- [ ] Automated conflict detection
- [ ] Extension marketplace scoring
- [ ] Installation time optimization

## Support

For issues with extension testing:

1. **Review Logs**: Check GitHub Actions workflow logs
2. **Test Locally**: Reproduce on your own test VM
3. **Open Issue**: Report problems with test workflow
4. **Contribute**: Submit PRs to improve testing

## Related Documentation

- [Extension Development Guide](CUSTOMIZATION.md#extension-system)
- [Extension README](../docker/lib/extensions.d/README.md)
- [Integration Testing](../github/workflows/integration.yml)
- [Validation Testing](../github/workflows/validate.yml)
