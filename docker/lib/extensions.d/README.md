# Extension System

This directory contains example extension scripts for customizing your development environment. Extensions are
automatically executed during the `vm-configure.sh` process.

## How Extensions Work

1. **Naming Convention**: Extensions are executed in alphabetical order
2. **Execution Phases**: Use prefixes to control when extensions run:
   - `pre-*.sh` - Run before main tool installation
   - `*.sh` - Run during main installation phase
   - `post-*.sh` - Run after all main tools are installed

## Creating Extensions

1. Create a script file in this directory (e.g., `50-rust.sh`)
2. Make it executable: `chmod +x 50-rust.sh`
3. Source common utilities: `source /workspace/scripts/lib/common.sh`
4. Use print functions for consistent output

## Example Extension

```bash
#!/bin/bash
# 50-rust.sh - Install Rust toolchain

# Source common utilities for print functions
source /workspace/scripts/lib/common.sh

print_status "Installing Rust toolchain..."

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env

# Install additional tools
cargo install cargo-watch cargo-edit

print_success "Rust toolchain installed successfully"
```

## Available Examples

### Language & Runtime Environments

- `10-rust.sh.example` - Rust toolchain installation
- `20-golang.sh.example` - Go toolchain installation
- `40-jvm.sh.example` - JVM languages (Java, Kotlin, Scala, Clojure) with SDKMAN
- `50-php.sh.example` - PHP 8.3 and Symfony framework development
- `60-ruby.sh.example` - Ruby with Rails and Sinatra frameworks
- `70-dotnet.sh.example` - .NET SDK with ASP.NET Core and development tools

### Tools & Utilities

- `30-docker.sh.example` - Docker tools installation
- `80-infra-tools.sh.example` - Curated infrastructure tooling
- `post-50-cleanup.sh.example` - Post-installation cleanup

## Best Practices

1. **Use numbered prefixes** (10-, 20-, etc.) to control execution order
2. **Source common.sh** for consistent logging and utilities
3. **Handle errors gracefully** - don't exit on minor failures
4. **Check for existing installations** before attempting to install
5. **Use appropriate print functions** for user feedback

## Debugging

Set `DEBUG=true` environment variable to see detailed execution logs:

```bash
DEBUG=true /workspace/scripts/vm-configure.sh --extensions-only
```
