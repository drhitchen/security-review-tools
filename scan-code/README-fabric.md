# Fabric Setup and Usage Guide

## Overview

[Fabric](https://github.com/danielmiessler/fabric) is a framework for enhancing security analysis with AI. In the security-review-tools repository, Fabric is used to generate comprehensive security reports based on scan results through `fabric_reports.sh`.

## Initial Setup

### Step 1: Install Homebrew (if needed)

```sh
# If you don't have Homebrew yet, install it following their installation guide 
# or from https://brew.sh/
```

### Step 2: Install Go and Fabric

```sh
# Install Go (required for Fabric)
brew install go

# Install Fabric and YouTube tool
go install github.com/danielmiessler/fabric@latest
go install github.com/danielmiessler/yt@latest

# Add Go binaries to your PATH
echo "# Go binaries" >> ~/.zshrc
echo "export PATH=\$PATH:~/go/bin" >> ~/.zshrc
source ~/.zshrc

# Complete Fabric setup
fabric --setup
fabric --updatepatterns
```

## Updating Fabric

To keep Fabric and its patterns up to date:

```sh
# Update the Fabric CLI
go install github.com/danielmiessler/fabric@latest
go install github.com/danielmiessler/yt@latest

# Update Fabric patterns
fabric --updatepatterns
```

## Working with Fabric Patterns

### List Available Patterns

To see all available Fabric patterns:

```sh
# List all patterns
fabric --listpatterns

# Filter for specific patterns
fabric --listpatterns | grep security
```

### Count and Enumerate Patterns

```sh
# Count with nicely formatted numbers
fabric --listpatterns | awk 'NR<=0 {print; next} {sub(/^\t/, ""); print "\t" NR "\t" $0}'

# Simply count the total number of patterns
fabric --listpatterns | wc -l
```

## Enhanced Markdown Formatting

For better visualization of Fabric-generated reports, install the following tools:

```sh
# Install mdcat (terminal markdown renderer with syntax highlighting)
brew install mdcat

# Install glow (another terminal markdown renderer with more styling options)
brew install glow
```

Examples of usage:

```sh
# View reports with mdcat
mdcat ./output/code-scans/myrepo/reports/fabric_summary_1.md

# View reports with glow
glow ./output/code-scans/myrepo/reports/fabric_summary_1.md
```

## Using Fabric with security-review-tools

The main integration point is `fabric_reports.sh`, which:

1. Takes scan summaries from security tools
2. Prepares them as prompts using `code2prompt`
3. Sends them to Fabric for analysis
4. Saves comprehensive reports in the `reports/` directory

To run this process:

```sh
# Syntax
./fabric_reports.sh -r <repo_folder> [-o <output_directory>] [-m <model>]

# Example
./fabric_reports.sh -r ~/code/my-application
```

Available options:
- `-r`: Repository folder (required)
- `-o`: Custom output directory (optional)
- `-m`: Specific model to use (optional, defaults to "chatgpt-4o-latest")

## Understanding Fabric Reports

The script generates three different reports:

1. **Basic Summary** (`fabric_summary_1_*.md`)
   - Concise overview of identified issues
   - Source files, line numbers, CVE/CWE references

2. **Detailed Summary with Tables** (`fabric_summary_2_*.md`)
   - More comprehensive analysis 
   - Tabular summaries for easier consumption
   - Categorized vulnerabilities

3. **Security Requirements** (`fabric_summary_requirements_*.md`)
   - Recommended security controls and guardrails
   - Actionable remediation steps
   - Production readiness recommendations

## Troubleshooting

If you encounter issues with Fabric:

1. **API Rate Limits**: The script includes pauses between API calls to avoid rate limits. If you encounter rate limit errors, wait a few minutes and try again.

2. **Model Availability**: If a specific model is unavailable, try running without the `-m` flag to use the default model.

3. **Token Size Issues**: If you receive errors about token limits, ensure you have `code2prompt` installed:
   ```sh
   brew install code2prompt
   ```

4. **Path Issues**: If Fabric isn't found, ensure your PATH includes Go binaries:
   ```sh
   echo $PATH | grep go/bin
   ```

## Models and Configuration

Fabric supports several models. For security reviews, recommended models include:

- `chatgpt-4o-latest` (default)
- `claude-3-7-sonnet-latest`

To see all available models:

```sh
fabric --listmodels
```

## Further Resources

- [Fabric GitHub Repository](https://github.com/danielmiessler/fabric)
- [Fabric Documentation](https://github.com/danielmiessler/fabric/blob/main/README.md)
- [code2prompt Repository](https://github.com/mufeedvh/code2prompt)
