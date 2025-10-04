# Code Security Scanning Tools

## Overview

The `scan-code` directory provides a set of automated tools for performing security assessments on source code repositories. These tools help identify vulnerabilities, misconfigurations, and potential security risks in infrastructure-as-code, dependencies, and application logic.

## Directory Structure

```text
scan-code
├── scan-code.sh                     # Main script for running security scans on source code
├── scan-code-claude.sh              # Master script for AI-powered security scans using Claude
├── scan-code-claude-modular.sh      # Targeted AI security analysis with focused prompts
├── scan-code-claude-metaprompt.sh   # Comprehensive AI security analysis with single metaprompt
├── bearer_summary.sh                # Summary script for Bearer security scans
├── checkov_summary.sh               # Summary script for Checkov scans
├── semgrep_summary.sh               # Summary script for Semgrep scans
├── snyk_summary.sh                  # Summary script for Snyk scans
├── terrascan_summary.sh             # Summary script for Terrascan scans
├── trivy_summary.sh                 # Summary script for Trivy scans
├── summarize_scans.sh               # Script to run all tool summaries automatically
└── fabric_reports.sh                # Fabric-based summarization script for code scan outputs
```

## Supported Security Tools

### Traditional Security Scanners

The following security tools can be run via **`scan-code.sh`**:

- **[SCC](https://github.com/boyter/scc)** – Source code complexity and line count analysis  
- **[Detect-Secrets](https://github.com/Yelp/detect-secrets)** – Detect secrets and credentials in code  
- **[TruffleHog](https://github.com/trufflesecurity/trufflehog)** – Identify high-entropy secrets in Git commits  
- **[Checkov](https://github.com/bridgecrewio/checkov)** – Infrastructure-as-code security scanner  
- **[KICS](https://github.com/Checkmarx/kics)** – Static analysis for IaC (Terraform, CloudFormation, etc.)  
- **[Semgrep](https://github.com/returntocorp/semgrep)** – Code security analysis with customizable rules  
- **[Trivy](https://github.com/aquasecurity/trivy)** – Security scanner for dependencies and container images  
- **[Snyk](https://github.com/snyk/snyk)** – Vulnerability scanning for code and dependencies  
- **[Bearer](https://github.com/Bearer/bearer)** – Identifies security & privacy risks in applications  
- **[Terrascan](https://github.com/tenable/terrascan)** – Security scanner for Terraform configurations

### AI-Powered Security Analysis

Additionally, AI-driven analysis scripts leverage **Anthropic’s Claude** (including *Claude 3.7 Sonnet* and *Claude Code*):

- **Modular Analysis** – Targeted security assessment using domain-specific prompts (`scan-code-claude-modular.sh`)  
- **Metaprompt Analysis** – Comprehensive all-in-one security assessment (`scan-code-claude-metaprompt.sh`)  

#### Claude Code Reference Links

- [Claude 3.7 Sonnet and Claude Code Announcement](https://www.anthropic.com/news/claude-3-7-sonnet)
- [Claude Code Overview](https://docs.anthropic.com/en/docs/agents-and-tools/claude-code/overview)
- [Claude Code GitHub Repo](https://github.com/anthropics/claude-code)

---

## Requirements

Below are the **minimal requirements** to run `scan-code.sh` and the associated summary scripts.

### For Traditional Security Tools

- **Python 3** for many of these tools  
- **Docker** (optional) if you prefer containerized versions (e.g., for KICS)  
- **AWS CLI** (optional) if scanning AWS-related code  

If you’re on **macOS**, you can install the primary security tools and utilities via **Homebrew**:

```sh
# Brew update
brew update

# Bearer
brew install bearer/tap/bearer

# Checkov
brew install checkov

# Code2Prompt
brew install code2prompt

# Detect-Secrets
brew install detect-secrets

# Glow (markdown formatting in the CLI)
brew install glow

# jq (JSON processor)
brew install jq

# KICS
brew install kics

# mdcat (markdown formatting in the CLI)
brew install mdcat

# Pyenv
brew install pyenv

# SCC (Sloc Cloc and Code)
brew install scc

# Semgrep
brew install semgrep

# Snyk
brew tap snyk/tap
brew install snyk-cli

# Terrascan
brew install terrascan

# Trivy
brew install trivy

# Trufflehog
brew install trufflehog

# Brew upgrade
brew upgrade

# Brew cleanup
brew cleanup
```

**Tip**: If using `Snyk` or `Semgrep`, you’ll need to log in or authenticate:
> ```sh
> # Login to Semgrep
> semgrep login
>
> # Login to Snyk
> snyk auth
>
> # Also, enable "code" scanning in the Snyk web console
> ```

### For Fabric-Based Summaries

- [**Fabric**](https://github.com/danielmiessler/fabric) – [Installation and update instructions](README-fabric.md)
- [**code2prompt**](https://github.com/mufeedvh/code2prompt) – Used to chunk or tokenize summary files before sending to Fabric  

### For AI-Powered Analysis (Claude)

- **Claude CLI** – The Anthropic CLI for interacting with Claude  
- **Anthropic API Key** – Must be configured to run Claude-based scripts  

---

## Usage

### 1. Running a Traditional Code Security Scan

To perform a security scan on a local source code repository, run:

```sh
./scan-code.sh -r <repo_folder>
```

By default, results go to `./output/code-scans/<repo_folder>`. You can override the output path:

```sh
./scan-code.sh -r <repo_folder> -o <output_directory>
```

### 2. Running Specific Tools

You can limit which tools to run via the `-t` flag:

```sh
./scan-code.sh -r <repo_folder> -t semgrep
```
Or multiple tools (comma-separated):
```sh
./scan-code.sh -r <repo_folder> -t semgrep,snyk,checkov
```

### 3. Summaries

After scanning, you can generate summaries for each tool individually, e.g.:

```sh
./semgrep_summary.sh -r <repo_folder>
./checkov_summary.sh -r <repo_folder>
... etc.
```

Or **automatically run all summaries**:

```sh
./summarize_scans.sh -r <repo_folder>
```

This will invoke each `_summary.sh` script in the directory.

### 4. Fabric-Based Summaries

If you have [Fabric CLI](https://github.com/fabric-oss/fabric) installed, you can run a deeper summarization process using:

```sh
./fabric_reports.sh -r <repo_folder> [-o <output_dir>] [-m <model>]
```

**What this does**:

1. Collects raw scan outputs & existing summary files in `<output_dir>`  
2. Converts them into prompts (via `code2prompt`, if available)  
3. Passes them to Fabric, producing consolidated Markdown reports under `<output_dir>/reports/`

You can specify a custom LLM model (e.g., `-m my-cool-model`) if Fabric supports it. Otherwise, it will use a default model.

### 5. AI-Assisted Security Reviews with Claude

Use the **Claude-based** scanning scripts to perform AI-assisted security reviews:

```sh
# Full AI-based scan
./scan-code-claude.sh -r <repo_folder> -b
```

**Options**:
- `-m`: Run modular prompts only  
- `-M`: Run metaprompt analysis only  
- `-b`: Run both modular and metaprompt analyses (default)

---

## Output Structure

Security scan outputs generally appear in `./output/code-scans/<repo_name>`:

```
output/
└── code-scans/
    └── <repo_name>/
        ├── scans/       # Raw outputs (JSON, HTML, CSV, etc.)
        ├── summaries/   # Post-processed summaries
        ├── logs/        # Execution logs
        └── reports/     # Consolidated final reports (e.g., from fabric_reports.sh)
```

For AI-based scans, a separate folder may be created under `./output/claude-scans/<repo_name>`.

---

## License

This project is licensed under the MIT License. See the [LICENSE](../LICENSE) file for details.

## Contributions

Contributions and improvements are welcome! Please fork the repository and submit pull requests for enhancements or additional security scanning scripts.

## Author

Developed by **Doug Hitchen** ([GitHub](https://github.com/drhitchen)).
