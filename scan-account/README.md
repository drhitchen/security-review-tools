# AWS Account Security Scan

## Overview

The **AWS Account Security Scan** project is a set of automated scripts designed to gather security-related information, scan an AWS account for vulnerabilities, and generate summary reports using **Prowler**, **ScoutSuite**, and additional security tools. These tools help assess compliance and security posture for AWS environments.

## Workflow

This project follows a structured workflow:

1. [**recon-account.sh**](recon-account.sh)  
   Performs reconnaissance on the AWS account, collecting details on enabled regions, security groups, IAM roles, and general account configuration.

2. [**scan-account.sh**](scan-account.sh)  
   Executes security scans using **Prowler** (for compliance checks) and **ScoutSuite** (for deep security assessments).

3. [**prowler_summary.sh**](prowler_summary.sh)  
   Analyzes Prowler scan results and generates summarized reports.

4. [**scout_summary.sh**](scout_summary.sh)  
   Extracts and formats ScoutSuite scan results for easier review.

These scripts produce a **consistent folder structure** under `./output/account-scans/<AWS_ACCOUNT_ID>` by default, separating **logs**, **scans**, and **summaries** for clarity.

## Prerequisites

Before using this project, ensure you have the following installed:

- **AWS CLI**
- **[Prowler](https://github.com/prowler-cloud/prowler)** (`prowler` command)
- **[ScoutSuite](https://github.com/nccgroup/ScoutSuite)** (`scout` command)
- **[jq](https://formulae.brew.sh/formula/jq)** (`jq` for JSON processing)
- **bash** (or a compatible shell)

### Dependency Installation

To set up the project and install dependencies, follow these steps:

```sh
# Clone the repository
git clone https://github.com/drhitchen/security-review-tools.git
cd security-review-tools

# Create a virtual environment
virtualenv -p python3 venv
source venv/bin/activate

# Install required dependencies
pip install --upgrade -r requirements.txt
cd account-scans
chmod +x *.sh
```

### AWS Configuration

Ensure you have AWS credentials configured either via `aws configure` or by setting environment variables (`AWS_PROFILE`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`).

## Usage

### 1. Reconnaissance (`recon-account.sh`)

```sh
./recon-account.sh -a <AWS_ACCOUNT_ID> \
                   [-p <AWS_PROFILE>] \
                   [-o <OUTPUT_DIR>]
```

This script gathers basic AWS account information, including:

- Enabled/disabled AWS regions  
- Security group configurations  
- IAM roles and policies  
- Other security-related metadata  

**Outputs**:  
- **Raw** recon data (e.g., region statuses, security groups, IAM details) in `scans/`.  
- **Log** file (manifest) in `logs/`.

### 2. Security Scanning (`scan-account.sh`)

```sh
./scan-account.sh -a <AWS_ACCOUNT_ID> \
                  [-p <AWS_PROFILE>] \
                  [-c <COMPLIANCE_FRAMEWORK>] \
                  [-o <OUTPUT_DIR>] \
                  [-t <TOOL>]
```

| Flag | Description                                                         | Default         |
|------|---------------------------------------------------------------------|-----------------|
| `-a` | AWS account number (or set `AWS_ACCOUNT` in `.env`)                 | *(required)*    |
| `-p` | AWS CLI profile                                                     | `default`       |
| `-c` | Prowler compliance framework                                        | `cis_1.5_aws`   |
| `-o` | Base output directory (raw + logs + summaries)                      | `$(pwd)/output` |
| `-t` | Which scan to run: `'prowler'`, `'scout'`, or `'both'`              | `both`          |

This script assumes an AWS role (if configured) and runs the scans, saving results in **structured output directories**.

### 3. Prowler Summary (`prowler_summary.sh`)

```sh
./prowler_summary.sh [<Prowler_Report_File>]
```

This script extracts key insights from Prowler scan results, including:

- Pass/Fail/Manual test summaries  
- Findings categorized by severity  
- Regional security summaries  

By default, it writes **summaries** to `summaries/` and logs to `logs/`.

### 4. ScoutSuite Summary (`scout_summary.sh`)

```sh
./scout_summary.sh [<ScoutSuite_Report_File>]
```

This script processes ScoutSuite results, displaying:

- Security group configurations  
- Enabled AWS regions with active resources  
- Detailed ingress rule analysis  

Likewise, it writes final summary files to `summaries/` and logs to `logs/`.

### 5. AWS Security Summary (`aws_security_summary.sh`)

```sh
./aws_security_summary.sh
```

Consolidates key findings from Prowler, ScoutSuite, and other tools into a **single** security report.

## Output Structure

```
<output_dir>/
└── account-scans/
    └── <AWS_ACCOUNT_ID>/
        ├── scans/
        │   ├── prowler/
        │   ├── scoutsuite/
        │   ├── iam/
        │   ├── networking/
        │   └── ...
        ├── summaries/
        ├── logs/
        └── reports/
```

1. **`scans/`** contains **raw** tool outputs (CSV, JSON, HTML, etc.).  
2. **`summaries/`** holds **summary** or **post-processed** results (e.g., pass/fail counts, region tallies).  
3. **`logs/`** stores **manifests** (script logs) and additional notes for each run.  
4. **`reports/`** holds **consolidated** security summaries.  

## Notes

- Ensure you have the **necessary AWS permissions** to run security scans (e.g., read access on security groups, IAM details, etc.).
- The output may contain **sensitive data**—handle it securely.
- Automate **role assumption** for enhanced security and access control.
- Summaries highlight **critical findings**; **raw** files hold in-depth details.

## License

This project is licensed under the MIT License. See the [LICENSE](../LICENSE) file for details.

## Contributions

Contributions and improvements are welcome! Please fork the repository and submit pull requests for enhancements or additional security scanning scripts.

## Author

Developed by **Doug Hitchen** ([GitHub](https://github.com/drhitchen)).
