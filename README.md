# Security Review Tools

## Overview

This repository provides a comprehensive suite of security review tools for conducting assessments on AWS accounts, source code repositories, GitHub organizations, and web applications. It includes automated scripts for reconnaissance, vulnerability scanning, and generating detailed summary reports.

## Directory Structure

```text
security-review-tools
├── LICENSE                         # MIT License file for the repository
├── README.md                       # This file - general overview of the repository
├── requirements.txt                # Dependencies for running the security review tools
├── tools/                          # Utility tools and templates
│   ├── add_paths.sh                # Script to add subfolders to your PATH
│   ├── cve_lookup.sh               # Script to look up CVE details
│   ├── repo2llm.sh                 # Script to prepare repositories for LLM analysis
│   ├── Findings Tracker.docx       # Template for tracking security findings
├── scan-account/                   # AWS account security scan scripts
│   ├── README.md                   # Detailed documentation for AWS security scanning
│   ├── recon-account.sh            # AWS account reconnaissance script
│   ├── scan-account.sh             # Main AWS security scanning script
│   ├── scout_summary.sh            # ScoutSuite summary script
│   ├── prowler_summary.sh          # Prowler summary script
├── scan-code/                      # Code security scanning tools
│   ├── README.md                   # Detailed documentation for code security scanning
│   ├── README-python.md            # Guide for Python environment setup
│   ├── README-fabric.md            # Guide for Fabric setup and usage
│   ├── scan-code.sh                # Script for scanning source code security issues
│   ├── scan-code-claude.sh         # Master script for Claude-based code scanning
│   ├── scan-code-claude-modular.sh # Script for modular Claude code scanning
│   ├── scan-code-claude-metaprompt.sh # Script for meta-prompt based Claude code scanning
│   ├── bearer_summary.sh           # Bearer summary script
│   ├── checkov_summary.sh          # Checkov summary script
│   ├── semgrep_summary.sh          # Semgrep summary script
│   ├── snyk_summary.sh             # Snyk summary script
│   ├── terrascan_summary.sh        # Terrascan summary script
│   ├── trivy_summary.sh            # Trivy summary script
│   ├── summarize_scans.sh          # Script to run all summary scripts automatically
│   ├── fabric_reports.sh           # Fabric-based summarization script for code scans
├── scan-github/                    # GitHub organization security scan tools
│   ├── README.md                   # Documentation for GitHub search tools
│   ├── github_search.py            # Iterates through orgs for separate searches
│   ├── github_search_actions.py    # Scans GitHub workflows for third-party actions
│   ├── github_search_browser.py    # Opens GitHub UI search in a browser
│   ├── requirements.txt            # Dependencies for GitHub search tools
├── scan-web/                       # Web application security scanning tools
│   ├── README.md                   # Documentation for web security scanning tools
│   ├── scan-ssl-tls.py             # Scans SSL/TLS configurations using sslscan
│   ├── scan-cookies.py             # Analyzes browser cookies for security risks
│   ├── scan-headers.sh             # Checks HTTP security headers for best practices
│   ├── requirements.txt            # Dependencies required for Python-based tools
├── check-security-tools.sh         # Script to verify required tools are installed
├── install-security-tools.sh       # Automated installation script for all required tools
```

## Setup

### Prerequisites

Before running the security review tools, ensure you have the following installed:

- **Python 3**
- **Virtual environment** (`venv` or `virtualenv`)
- Required Python packages (listed in `requirements.txt`)
- **AWS CLI** (for AWS account scanning)
- (Optional) [Fabric CLI](https://github.com/danielmiessler/fabric) for using `fabric_reports.sh`

### Quick Installation

For a quick setup, you can use the provided installation script:

```sh
# Make sure you have administrative privileges
cd "${HOME}/git/personal"
git clone https://github.com/drhitchen/security-review-tools.git
cd security-review-tools
chmod +x install-security-tools.sh check-security-tools.sh
./install-security-tools.sh
```

This script will:
1. Clone or update the repository
2. Install required Homebrew packages
3. Set up Python with pyenv
4. Create a virtual environment and install dependencies
5. Install all necessary security tools
6. Validate installation of security tools

### Verify tool installation

```sh
./check-security-tools.sh
```

### (Optional) Add scripts to your PATH

```sh
source tools/add_paths.sh
```

This script detects the local directories (`scan-account`, `scan-code`, `tools`) and adds them to your PATH for easier command-line usage.

## AWS Account Security Scan [scan-account](./scan-account/)

The [scan-account](scan-account/) directory contains scripts to conduct security assessments of AWS accounts using tools such as **Prowler** and **ScoutSuite**.

### Usage

1. **Activate the virtual environment**:

   ```sh
   source venv/bin/activate
   ```

2. **Ensure dependencies are up to date**:

   ```sh
   pip install --upgrade -r requirements.txt
   ```

3. **Run reconnaissance**:

   ```sh
   cd scan-account
   ./recon-account.sh -a <AWS_ACCOUNT_ID> -p <AWS_PROFILE>
   ```

4. **Run account scan**:

   ```sh
   ./scan-account.sh -a <AWS_ACCOUNT_ID> -p <AWS_PROFILE> -t both
   ```

For more details, refer to the [`scan-account/README.md`](scan-account/README.md).

## Code Security Scan [scan-code](scan-code/)

The [scan-code](scan-code/) directory contains scripts for scanning source code repositories for security vulnerabilities using multiple tools.

### Traditional Security Tool Scans

1. **Ensure dependencies are up to date**:

   ```sh
   pip install --upgrade -r requirements.txt
   ```

2. **Run code security scan**:

   ```sh
   cd scan-code
   ./scan-code.sh -r <repo_path>
   ```

3. **Run individual tool summaries**:

   - **Bearer:** `./bearer_summary.sh -r <repo_path>`
   - **Checkov:** `./checkov_summary.sh -r <repo_path>`
   - **Semgrep:** `./semgrep_summary.sh -r <repo_path>`
   - **Snyk:** `./snyk_summary.sh -r <repo_path>`
   - **Terrascan:** `./terrascan_summary.sh -r <repo_path>`
   - **Trivy:** `./trivy_summary.sh -r <repo_path>`

4. **Automatically run all summaries**:

   ```sh
   ./summarize_scans.sh -r <repo_path>
   ```

### AI-Assisted Security Reviews with Claude

Use the Claude-based scripts to perform AI-powered security reviews:

```sh
./scan-code-claude.sh -b -r <repo_path>
```

- `-m`: Run modular script only (targeted security domain prompts)  
- `-M`: Run meta-prompt script only (comprehensive single-prompt review)  
- `-b`: Run both scripts sequentially  

For more details, refer to the [`scan-code/README.md`](scan-code/README.md).

### Fabric-Based Summaries

If you have the [Fabric CLI](https://github.com/danielmiessler/fabric) installed, you can run a deeper summarization of your code scan outputs:

```sh
./fabric_reports.sh -r <repo_path>
```

## GitHub Organization Security Scan [scan-github](scan-github/)

The [scan-github](scan-github/) directory contains tools for searching across GitHub organizations within an enterprise setup. These tools help identify security risks in public and private repositories using the GitHub API or a web browser.

### Setup

1. Install dependencies:

   ```sh
   cd scan-github
   pip install -r requirements.txt
   ```

2. Set up a `.env` file with your GitHub token and enterprise endpoint (if applicable):

   ```ini
   GITHUB_TOKEN=<your_github_personal_access_token>
   GITHUB_ENTERPRISE=https://api.github.com  # Modify if using GitHub Enterprise
   ```

### Usage

- **Run a search across all organizations:**

  ```sh
  python github_search.py "search term"
  ```

- **Open search results in GitHub UI:**

  ```sh
  python github_search_browser.py "search term"
  ```

- **Scan GitHub Actions usage in repositories:**

  ```sh
  python github_search_actions.py
  ```
  
  This will identify GitHub Actions used in workflows, detect third-party dependencies, and save results to `third_party_actions_inventory.json`.

For more details, see [`scan-github/README.md`](scan-github/README.md).

## Web Application Security Scan [scan-web](./scan-web/)

The [scan-web](scan-web/) directory contains tools to analyze web applications' security posture, checking SSL/TLS configurations, HTTP security headers, and cookies.

### 1. SSL/TLS Security Scanner

**Tool:** `scan-ssl-tls.py`

```sh
python scan-ssl-tls.py <DOMAIN>
```

Example:

```sh
python scan-ssl-tls.py www.mydomain.com
```

### 2. Cookie Security Analyzer

**Tool:** `scan-cookies.py`

```sh
python scan-cookies.py <URL>
```

Example:

```sh
python scan-cookies.py https://www.mydomain.com
```

### 3. HTTP Security Headers Analyzer

**Tool:** `scan-headers.sh`

```sh
./scan-headers.sh <URL>
```

Example:

```sh
./scan-headers.sh https://www.mydomain.com
```

For more details, refer to the [`scan-web/README.md`](scan-web/README.md).

## Utility Tools [tools](tools/)

The [tools](tools/) directory provides additional utilities to support security assessments:

### `add_paths.sh`

Adds `scan-account`, `scan-code`, and `tools` directories to your PATH:

```sh
source tools/add_paths.sh
```

### `cve_lookup.sh`

Quickly retrieve information about CVEs:

```sh
./tools/cve_lookup.sh CVE-2023-12345
```

### `repo2llm.sh`

Prepare a repository for analysis with Large Language Models:

```sh
cd your-repository
../security-review-tools/tools/repo2llm.sh
```

**Options**:

- `-d <depth>`: Directory depth to analyze (default: 2)
- `-x <exclude>`: Comma-separated list of files/folders to exclude
- `-c <commits>`: Number of git commits to include (default: 5)

### Findings Tracker

A structured Word document template (`Findings Tracker.docx`) for tracking security findings across assessments.

## License

See the [LICENSE](LICENSE) file for details.

## Maintainer

Developed and maintained by **Doug Hitchen** ([GitHub](https://github.com/drhitchen)).
