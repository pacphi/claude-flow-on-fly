# Contributing

We welcome contributions to improve this remote AI-assisted development environment! Whether you're fixing bugs, adding features, improving documentation, or sharing extensions, your contributions help the entire community.

## Ways to Contribute

### Code Contributions

- **Bug Fixes**: Fix issues with VM setup, configuration, or scripts
- **Feature Additions**: Add new capabilities to the development environment
- **Performance Improvements**: Optimize resource usage or startup times
- **Security Enhancements**: Strengthen security measures or fix vulnerabilities

### Documentation

- **Setup Guides**: Improve installation and configuration documentation
- **Tutorials**: Create walkthroughs for specific use cases
- **API Documentation**: Document script functions and configuration options
- **Troubleshooting**: Add solutions for common issues

### Extensions

- **Language Support**: Add support for new programming languages
- **Tool Integrations**: Integrate popular development tools
- **Cloud Services**: Add integrations with cloud platforms
- **Workflow Automation**: Create productivity-enhancing automation

### Testing and Feedback

- **Environment Testing**: Test on different platforms and configurations
- **Bug Reports**: Report issues with detailed reproduction steps
- **Feature Requests**: Suggest improvements and new capabilities
- **User Experience**: Provide feedback on setup and usage workflows

## Getting Started

### Development Environment Setup

1. **Fork the Repository**

   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/YOUR-USERNAME/claude-flow-on-fly.git
   cd claude-flow-on-fly
   ```

2. **Set Up Development VM**

   ```bash
   # Deploy development environment
   ./scripts/vm-setup.sh --app-name contrib-dev --region iad

   # Connect and configure
   ssh developer@contrib-dev.fly.dev -p 10022
   /workspace/scripts/vm-configure.sh
   ```

3. **Create Feature Branch**

   ```bash
   git checkout -b feature/your-feature-name
   ```

### Project Structure

Understanding the codebase organization:

```
claude-flow-on-fly/
├── docker/                     # Container configuration
│   ├── config/                 # Configuration files
│   ├── context/                # AI context files
│   ├── lib/                    # Shared libraries and extensions
│   └── scripts/                # Container setup scripts
├── scripts/                    # VM management (local)
│   ├── lib/                    # Management libraries
│   └── vm-*.sh                 # VM lifecycle scripts
├── templates/                  # Configuration templates
├── docs/                       # Documentation
└── README.md                   # Main documentation
```

## Development Guidelines

### Code Standards

**Shell Scripting:**

```bash
#!/bin/bash
# Always use strict error handling
set -euo pipefail

# Source common utilities
source /workspace/scripts/lib/common.sh

# Use descriptive function names
function install_development_tool() {
    print_status "Installing development tool..."

    # Check prerequisites
    if ! command_exists curl; then
        print_error "curl is required"
        return 1
    fi

    # Installation logic here

    print_success "Development tool installed"
}
```

**Documentation:**

- Use clear, concise language
- Include code examples for all features
- Document prerequisites and assumptions
- Add troubleshooting sections

**Configuration:**

- Use environment variables for customization
- Provide sensible defaults
- Document all configuration options
- Validate configuration inputs

### Testing Requirements

**Local Testing:**

```bash
# Test script locally before submitting
./scripts/vm-setup.sh --app-name test-dev --region iad

# Validate configuration
ssh developer@test-dev.fly.dev -p 10022 "/workspace/scripts/validate-setup.sh"

# Clean up test environment
./scripts/vm-teardown.sh --app-name test-dev
```

**Extension Testing:**

```bash
# Test new extensions
cp docker/lib/extensions.d/your-extension.sh.example \
   docker/lib/extensions.d/your-extension.sh

# Deploy and test
flyctl deploy -a test-dev
ssh developer@test-dev.fly.dev -p 10022 "/workspace/scripts/vm-configure.sh --extensions-only"
```

**Security Testing:**

```bash
# Run security scans
shellcheck scripts/*.sh docker/scripts/*.sh
bandit -r docker/lib/ -f json

# Test with minimal permissions

ssh -o PasswordAuthentication=no -o PreferredAuthentications=publickey \
    developer@test-dev.fly.dev -p 10022
```

## Contribution Workflow

### Pull Request Process

1. **Create Feature Branch**

   ```bash
   git checkout -b feature/descriptive-name
   # or
   git checkout -b fix/bug-description
   ```

2. **Make Changes**

   - Write code following project standards
   - Add or update documentation
   - Include tests where applicable
   - Update CHANGELOG.md if significant

3. **Test Thoroughly**

   ```bash
   # Local testing
   ./scripts/validate-changes.sh

   # Deploy test environment
   ./scripts/vm-setup.sh --app-name pr-test --region iad

   # Verify changes work
   ssh developer@pr-test.fly.dev -p 10022 "your-test-commands"
   ```

4. **Commit Changes**

   ```bash
   # Use conventional commit format
   git add .
   git commit -m "feat: add support for Python data science stack"
   # or
   git commit -m "fix: resolve SSH key permission issues"
   # or
   git commit -m "docs: update setup guide with troubleshooting steps"
   ```

5. **Push and Create PR**

   ```bash
   git push origin feature/descriptive-name
   ```

   Then create a pull request on GitHub with:

   - Clear description of changes
   - Screenshots or examples if UI-related
   - Testing steps performed
   - Breaking changes noted

### Conventional Commits

Use these prefixes for commit messages:

- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation updates
- `style:` - Code formatting (no functional changes)
- `refactor:` - Code restructuring (no functional changes)
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks

## Extension Development

### Creating New Extensions

**Extension Template:**

```bash
#!/bin/bash
# docker/lib/extensions.d/##-extension-name.sh.example
# Description: Brief description of what this extension does
# Prerequisites: List any requirements
# Usage: How to enable and use this extension

# Load common utilities
source /workspace/scripts/lib/common.sh

print_status "Installing [Extension Name]..."

# Check prerequisites
if ! command_exists prerequisite-command; then
    print_error "Prerequisite not found: prerequisite-command"
    exit 1
fi

# Installation logic
install_packages package1 package2

# Configuration
cat > /workspace/config/extension-config << 'EOF'
# Extension configuration
SETTING1=value1
SETTING2=value2
EOF

# Post-installation setup
setup_extension_environment

print_success "[Extension Name] installed successfully"

# Usage instructions
cat << 'USAGE'
Extension installed! Usage:
  command1 --option     # Description
  command2              # Description

Configuration file: /workspace/config/extension-config
USAGE
```

**Extension Guidelines:**

- Use descriptive numbering (10-90 by category)
- Include comprehensive error checking
- Provide clear success/failure feedback
- Document prerequisites and usage
- Make extensions idempotent (safe to run multiple times)

### Documentation Standards

**File Headers:**

```bash
#!/bin/bash
# Script Name: descriptive-name.sh
# Description: What this script does
# Author: Your Name <email@example.com>
# Version: 1.0.0
# Last Modified: YYYY-MM-DD
#
# Usage: ./script-name.sh [options]
# Example: ./script-name.sh --option value
#
# Prerequisites:
# - Prerequisite 1
# - Prerequisite 2
```

**Function Documentation:**

```bash
# Description: Brief description of function purpose
# Parameters:
#   $1: Parameter description
#   $2: Parameter description (optional)
# Returns: Description of return value/behavior
# Example: example_usage param1 param2
function example_function() {
    local param1="$1"
    local param2="${2:-default_value}"

    # Function implementation
}
```

## Review Process

### Code Review Checklist

**Functionality:**

- [ ] Code works as intended
- [ ] Edge cases handled appropriately
- [ ] Error conditions managed gracefully
- [ ] Performance impact considered

**Security:**

- [ ] No secrets or credentials exposed
- [ ] Input validation implemented
- [ ] Proper file permissions set
- [ ] Security best practices followed

**Documentation:**

- [ ] Code is well-commented
- [ ] Usage examples provided
- [ ] Prerequisites documented
- [ ] Breaking changes noted

**Testing:**

- [ ] Changes tested in clean environment
- [ ] Extension compatibility verified
- [ ] Security implications assessed
- [ ] Performance impact measured

### Continuous Integration

**Automated Checks:**

- Shellcheck for script validation
- Security scanning for vulnerabilities
- Documentation link validation
- Example code testing

**Manual Review:**

- Code quality and maintainability
- User experience impact
- Security implications
- Documentation completeness

## Release Process

### Versioning

We use semantic versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Breaking changes to APIs or workflows
- **MINOR**: New features, backward-compatible
- **PATCH**: Bug fixes, security updates

### Release Checklist

**Pre-release:**

- [ ] All tests passing
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version numbers bumped
- [ ] Security scan clean

**Release:**

- [ ] Tagged release created
- [ ] Release notes published
- [ ] Documentation deployed
- [ ] Community notified

## Community Guidelines

### Communication

- **Be Respectful**: Treat all contributors with respect
- **Be Constructive**: Provide helpful feedback and suggestions
- **Be Collaborative**: Work together to improve the project
- **Be Patient**: Remember everyone has different experience levels

### Getting Help

- **GitHub Issues**: Report bugs and request features
- **Discussions**: Ask questions and share ideas
- **Documentation**: Check existing docs first
- **Community**: Connect with other contributors

### Recognition

Contributors are recognized through:

- Git commit attribution
- Release notes mentions
- Documentation acknowledgments
- Community highlighting

## Roadmap

### Short-term Goals

- Improved extension system
- Enhanced security features
- Better cost optimization tools
- Expanded language support

### Medium-term Goals

- Multi-region deployment templates
- Advanced monitoring and alerting
- CI/CD integration templates
- Team collaboration features

### Long-term Vision

- Full infrastructure-as-code support
- Enterprise-grade security and compliance
- AI-powered development optimization
- Global developer community platform

## Questions?

- Check existing [Issues](https://github.com/pacphi/claude-flow-on-fly/issues)
- Start a [Discussion](https://github.com/pacphi/claude-flow-on-fly/discussions)
- Review [Documentation](docs/)
- Contact maintainers

Thank you for contributing to the future of AI-assisted remote development! 🚀
