# Linux Installation Guide

## Overview

This security-review-tools repository has been updated to support Linux (Ubuntu 24.04.2) using a modular installation framework. The tools are now installed using isolated pyenv virtual environments and system package managers instead of Homebrew.

## Prerequisites

Before running the security review tools on Linux, ensure you have:

- **Ubuntu 24.04.2** (or compatible Linux distribution)
- **Git** for repository management
- **Administrative privileges** (sudo access)
- **Modular Installation Framework** available at `~/Downloads/install/`

## Quick Installation for Linux

### 1. Set up the modular installation framework

First, ensure you have the modular installation framework available:

```sh
# This should contain install-*.sh scripts for each security tool
ls ~/Downloads/install/install-*.sh
```

### 2. Install security-review-tools for Linux

```sh
# Clone the repository
cd "${HOME}/git/personal"
git clone https://github.com/drhitchen/security-review-tools.git
cd security-review-tools

# Run the Linux installation script
chmod +x install-security-tools-linux.sh
./install-security-tools-linux.sh
```

This script will:
1. Install pyenv and Python 3.12.11 if needed
2. Create a virtual environment for the security-review-tools
3. Install all required security tools using the modular framework
4. Set up proper PATH and wrapper configurations

### 3. Verify tool installation

```sh
./check-security-tools.sh
```

### 4. Authenticate tools that require it

```sh
# Activate the virtual environment first
source .venv/bin/activate

# Log into Semgrep
semgrep login

# Authenticate Snyk
snyk auth
```

## Tool Installation Locations

The Linux modular framework installs tools in the following locations:

### System Tools (available in `/usr/local/bin/`)
- `bearer` - Installed via APT
- `kics` - Built from source, installed to `/usr/local/bin/`
- `scc` - Downloaded binary, installed to `/usr/local/bin/`
- `snyk` - Downloaded binary, installed to `/usr/local/bin/`
- `terrascan` - Downloaded binary, installed to `/usr/local/bin/`
- `trivy` - Installed via APT repository
- `trufflehog` - Downloaded binary, installed to `/usr/local/bin/`

### Python Tools (via pyenv virtual environments)
- `checkov` - In `checkov-env` virtual environment
- `detect-secrets` - In `detect-secrets-env` virtual environment  
- `semgrep` - In `semgrep-env` virtual environment

All Python tools have wrapper scripts in `/usr/local/bin/` that activate the appropriate virtual environment.

## Usage

### Activate the environment

```sh
cd ~/git/personal/security-review-tools
source .venv/bin/activate
```

### Run code security scans

```sh
cd scan-code
./scan-code.sh -r <repo_path>
```

### Run individual tool summaries

```sh
./bearer_summary.sh -r <repo_path>
./checkov_summary.sh -r <repo_path>
./semgrep_summary.sh -r <repo_path>
# ... etc
```

### Run all summaries automatically

```sh
./summarize_scans.sh -r <repo_path>
```

## Differences from Mac Installation

| Aspect | Mac (Homebrew) | Linux (Modular) |
|--------|----------------|-----------------|
| Package Manager | Homebrew | APT + Direct downloads |
| Python Environment | Single .venv | pyenv + isolated environments |
| Tool Locations | `/opt/homebrew/bin/` | `/usr/local/bin/` (wrappers) |
| Installation Method | `brew install` | Individual `install-*.sh` scripts |

## Troubleshooting

### Tools not found
If tools are not found in PATH, verify the modular installation completed:

```sh
ls -la /usr/local/bin/ | grep -E "(bearer|checkov|detect-secrets|kics|scc|semgrep|snyk|terrascan|trivy|trufflehog)"
```

### Python environment issues
If Python tools don't work, check the pyenv environments:

```sh
pyenv versions
# Should show: checkov-env, detect-secrets-env, semgrep-env
```

### Missing modular framework
If the installation fails to find the modular framework:

```sh
# Ensure you have the framework at the expected location
ls ~/Downloads/install/install-*.sh
```

## Updating Tools

To update individual tools, run their respective install scripts:

```sh
cd ~/Downloads/install/
./install-semgrep.sh  # Updates semgrep to latest version
./install-trivy.sh    # Updates trivy to latest version
# etc.
```

## Maintainer

Updated for Linux compatibility by **Doug Hitchen** ([GitHub](https://github.com/drhitchen)).
