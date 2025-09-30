# Changelog

All notable changes to this project will be documented in this file.

All notable changes to this project will be documented in this file.

All notable changes to this project will be documented in this file.

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0-beta.2] - 2025-09-30

### ✨ Features

* feat: add Goalie research assistant integration (c281b3b)

### 🐛 Bug Fixes

* fix: resolve sed compatibility issue in prepare-fly-config.sh for Linux/macOS (e4718d1)
* fix: improve fly.toml management and cross-platform compatibility (751ff67)

### 📚 Documentation

* docs: update CHANGELOG.md for v1.0.0-beta.1 (d286242)


### 📦 Installation

To use this version:

```bash
git clone https://github.com/pacphi/claude-flow-on-fly.git
cd claude-flow-on-fly
git checkout v1.0.0-beta.2
./scripts/vm-setup.sh --app-name my-claude-dev
```

**Full Changelog**: https://github.com/pacphi/claude-flow-on-fly/compare/v1.0.0-beta.1...v1.0.0-beta.2

## [1.0.0-beta.1] - 2025-09-23

### 🐛 Bug Fixes

* fix: resolve volume persistence file content loss during machine restart (6cf371e)

### 📚 Documentation

* docs: update CHANGELOG.md for v1.0.0-alpha.1 (2315ac3)

### 🔧 Other Changes

* ci: improve integration workflow robustness and add CI troubleshooting docs (5e60c81)
* Beta features (#6) (f871f79)


### 📦 Installation

To use this version:

```bash
git clone https://github.com/pacphi/claude-flow-on-fly.git
cd claude-flow-on-fly
git checkout v1.0.0-beta.1
./scripts/vm-setup.sh --app-name my-claude-dev
```

**Full Changelog**: https://github.com/pacphi/claude-flow-on-fly/compare/v1.0.0-alpha.1...v1.0.0-beta.1

## [1.0.0-alpha.1] - 2025-09-22

### ✨ Features

* feat: implement comprehensive project automation and achieve 0 markdown violations (dd86801)
* feat: enhance new-project.sh with intelligent type detection and flexible configuration (d6807a5)

### 🐛 Bug Fixes

* fix: resolve AWK string escaping issue in release workflow changelog generation (5eaa038)
* fix: replace regex patterns with bash pattern matching in release workflow (f707917)
* fix: improve GitHub workflows security and shell script quality (d2c0a4b)
* fix: resolve all GitHub workflow validation failures (3b796ed)
* fix: resolve GitHub workflow failures and improve CI reliability (9c3eb6e)
* (fix) Paths for available scripts in show_environment_status() in vm-configure.sh (4fde63b)
* (fix) Adjust backup logic, whether vm-configure.sh is running on Fly.io VM, and add troubleshooting docs (9f4be32)
* (fix) Adjust package name for netcat installation (c263077)
* (fix) Documentation improvements (6a2ad8a)
* (fix) Parsing and output issues with suspend and resume scripts (033a670)
* (fix) Parsing and output issues with cost-monitor script (f0f8f84)
* (fix) Properly display machine lists, volume information, and app status when running the teardown command (fdeac74)
* (fix) Remove trailing whitespace from teardown script (1b66ff6)
* (fix) Make sure vm-configure.sh is available in workspace/scripts directory of VM (5737bf9)
* (fix) Volume cost calculation in teardown script (b5096dc)
* (fix) Reorder placeholder replacement in setup (45100f0)
* (fix) Refactor Docker image builds
  * Decompose Dockerfile embedded scripts and configuration into individual scripts and configuration in a docker directory
  which facilitates local image build testing * Add placeholders to fly.toml (c4c5fd8)
* (fix) Update link to fly.toml in README (9d0ffc4)

### 📚 Documentation

### 📦 Dependencies

* docker(deps): bump ubuntu from 22.04 to 24.04 (e4167a1)
* ci(deps): bump softprops/action-gh-release from 1 to 2 (#5) (9a9b06c)
* ci(deps): bump actions/github-script from 7 to 8 (#4) (e23f4d2)

### 🔧 Other Changes

* Add option to configure a single extension (64c155e)
* Prune sections (f542e41)
* Improve documentation - consolidate, eliminate redundancies and address inaccuracies (e70d72d)
* Revise claim based on actual count of agents from Github repository (7bd00f2)
* Polish (c40d09f)
* Command reference link updated (d7e05ae)
* Remove trailing whitespace (1042de1)
* Reorganized and revised documentation (093cea1)
* Major infrastructure and tooling improvements (c25f2ae)
* Remove trailing whitespace (3138d65)
* Add capability to clone and/or fork Git repositories (06fb248)
* Fix issues wih agent-duplicates, agent-validate-all, and agent-find aliases - and adjust refs to cf
(e.g. cf swarm -> cf-swarm) (25bf688)
* Remove trailing whitespace (4488faa)
* Add extension-manager - Simplify activation and deactivation of pre-install, install, and post-install user scripts (10edf9b)
* Enhance post-cleanup to account for 100+ tools across all ecosystems (0a194bc)
* More tweaks to aliases (691681d)
* Tweaks to aliases (f40b179)
* Update respository structure (89254b4)
* Revise section on Automated Setup (ebfd89d)
* Integrate turbo flow (#2) (f98f8f0)
* Add infrastructure tooling example to extensions (eeac728)
* Trim trailing whitespace (8cd519f)
* Add support for other languages/frameworks (5bb1ecb)
* Refactor workspace script generation to use external script files (b15622d)
* Update VM state handling to support suspended status and improve messaging (b3c9758)
* Refactor scripts with shared library system and extension support (9620ee9)
* Add LICENSE (46d7888)
* Move QUICKSTART.md and SETUP.md to docs directory - and fix all references in existing documentation (f5b2b22)
* Remove http service configuration (it's not required) (7d7a088)
* Remove npm/yarn, pip, github-actions configurations from Dependabot workflow - We don't have any need for these yet (caeac64)
* Add Dependabot Github workflow (5630df2)
* Add placeholders for cpus and cpu_kind in fly.toml
  * Make necessary updates to setup script and documentation (8f1856b)
* Add vm-teardown.sh script (64345b9)
* Add QUICKSTART.md
  * Emphasis on getting up and runnng fast and efficiently
  * Formatting updates across existing documentation (75489bb)


### 📦 Installation

To use this version:

```bash
git clone https://github.com/pacphi/claude-flow-on-fly.git
cd claude-flow-on-fly
git checkout v1.0.0-alpha.1
./scripts/vm-setup.sh --app-name my-claude-dev
```

**Full Changelog**: https://github.com/pacphi/claude-flow-on-fly/compare/2422242859bc120201554c7d2fb19d859b877665...v1.0.0-alpha.1

## [Unreleased]

### ✨ Added

- GitHub workflow automation for project validation
- Integration testing with ephemeral Fly.io deployments
- Automated release management with changelog generation
- Dependabot configuration for automated dependency updates
- Comprehensive issue templates for bug reports, feature requests, and questions
- Pull request template with detailed checklists
- Security scanning with Trivy and GitLeaks
- Markdown linting and documentation validation

### 🔧 Changed

- Enhanced project structure with `.github/` directory for automation
- Improved development workflow with automated validation

### 📚 Documentation

- Added workflow documentation and examples
- Created comprehensive templates for community contributions

## [Previous Releases]

_Previous releases and their changes will be documented here as they are tagged._

---

**Note**: This project follows semantic versioning. For a detailed list of changes between versions,
see the [GitHub releases page](https://github.com/pacphi/claude-flow-on-fly/releases).
