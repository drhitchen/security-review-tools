# KICS Queries Installation Guide

This document explains how to properly install KICS queries for use with the security scanning tools.

## Background

KICS (Keeping Infrastructure as Code Secure) requires separate query files to perform security scans. Modern KICS installations don't include queries by default - they need to be downloaded separately from the [official KICS repository](https://github.com/Checkmarx/kics).

## Installation Options

### Option 1: Local Installation (Recommended)

Install queries to the local `assets/queries` directory within the scan-code folder:

```bash
cd scan-code
./install-kics-queries.sh --local
```

**Advantages:**
- No root privileges required
- Queries are version-controlled with your scanning tools
- Easy to update or customize
- Portable across different systems

**Location:** `./scan-code/assets/queries/`

### Option 2: System Installation

Install queries to the system directory for all users:

```bash
cd scan-code
sudo ./install-kics-queries.sh --system
```

**Advantages:**
- Available system-wide for all users
- Follows standard Linux installation patterns
- Single installation for multiple projects

**Location:** `/usr/local/share/kics/assets/queries/`

### Option 3: Docker-based KICS (Alternative)

Use the official KICS Docker image which includes queries:

```bash
# Pull the latest KICS Docker image
docker pull checkmarx/kics:latest

# Scan a directory using Docker
docker run -t -v "$(pwd):/path" checkmarx/kics:latest scan -p /path -o "/path/"
```

**Advantages:**
- Always includes the latest queries
- No local installation needed
- Consistent environment across systems
- Multiple variants available (alpine, debian, ubi8)

### Option 4: Manual Installation

If you prefer to install manually:

#### For Local Installation:
```bash
cd scan-code
mkdir -p assets
cd assets
git clone --depth 1 https://github.com/Checkmarx/kics.git temp-kics
cp -r temp-kics/assets/queries .
rm -rf temp-kics
```

#### For System Installation:
```bash
sudo mkdir -p /usr/local/share/kics/assets
cd /tmp
git clone --depth 1 https://github.com/Checkmarx/kics.git
sudo cp -r kics/assets/queries /usr/local/share/kics/assets/
rm -rf kics
```

## Verification

After installation, verify that KICS can find the queries:

```bash
# Test with a sample Terraform file
mkdir -p test-kics
echo 'resource "aws_instance" "example" { ami = "ami-123456" }' > test-kics/main.tf

# Run KICS scan
./scan-code.sh -r test-kics -t kics

# Clean up
rm -rf test-kics
```

## Query Search Order

The `scan-code.sh` script searches for KICS queries in this order:

1. `./scan-code/assets/queries` (local installation)
2. `./assets/queries` (relative to current directory)
3. `/usr/local/share/kics/assets/queries` (system installation)
4. `/opt/kics/assets/queries`
5. `/usr/share/kics/assets/queries`
6. `$HOME/go/src/github.com/Checkmarx/kics/assets/queries`
7. `$HOME/.local/share/kics/assets/queries`

## Updating Queries

### Local Installation:
```bash
cd scan-code
./install-kics-queries.sh --local
```

### System Installation:
```bash
cd scan-code
sudo ./install-kics-queries.sh --system
```

### Docker:
```bash
docker pull checkmarx/kics:latest
```

## Troubleshooting

### Error: "Unable to locate KICS queries directory"

This means KICS queries haven't been installed. Use one of the installation options above.

### Error: "git command not found"

Install git:
```bash
sudo apt-get update && sudo apt-get install git
```

### Permission Denied (System Installation)

Use sudo for system installation:
```bash
sudo ./install-kics-queries.sh --system
```

### Queries Out of Date

Re-run the installation command to get the latest queries:
```bash
./install-kics-queries.sh --local  # or --system
```

## Integration with Main Installation

The main installation script (`install-security-tools-linux.sh`) automatically installs KICS queries locally after installing KICS. You can also run the installation manually anytime.

## Query Statistics

After installation, you can check how many queries were installed:

```bash
# For local installation
find ./scan-code/assets/queries -name "*.rego" | wc -l

# For system installation  
find /usr/local/share/kics/assets/queries -name "*.rego" | wc -l
```

A typical installation includes 1000+ security queries covering multiple platforms (AWS, Azure, GCP, Kubernetes, Docker, etc.).