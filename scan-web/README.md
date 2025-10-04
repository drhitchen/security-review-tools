# Web Security Scanning Tools

## Overview

The `scan-web` directory contains automated tools for performing security assessments on web applications. These tools help identify weaknesses in SSL/TLS configurations, HTTP security headers, and cookies, ensuring a robust web security posture.

## Directory Structure

```text
scan-web
├── scan-ssl-tls.py       # Scans SSL/TLS configurations using sslscan
├── scan-cookies.py       # Analyzes browser cookies for security risks
├── scan-headers.sh       # Checks HTTP security headers for best practices
├── requirements.txt      # Dependencies required for Python-based tools
```

## Supported Security Tools

### 1. SSL/TLS Security Scanner

**Tool:** `scan-ssl-tls.py`\
**Description:** This script checks a website's SSL/TLS configuration using `sslscan`, identifying supported protocols, weak ciphers, and certificate details.

#### Features

- Identifies supported SSL/TLS versions (TLSv1.0/1.1/1.2/1.3, SSLv2/3)
- Flags weak and insecure cipher suites
- Displays certificate details (issuer, validity, RSA key strength)
- Provides links to additional online analysis (Qualys SSL Labs, Mozilla TLS guide)
- Categorizes protocols and ciphers by security best practices

**Usage:**

```sh
python scan-ssl-tls.py <DOMAIN>
```

Example:

```sh
python scan-ssl-tls.py www.mydomain.com
```

### 2. Cookie Security Analyzer

**Tool:** `scan-cookies.py`\
**Description:** This script uses Selenium to analyze cookies set by a website, checking security flags and identifying tracking cookies.

#### Features

- Detects missing `Secure`, `HttpOnly`, and `SameSite` attributes
- Identifies cookies used for tracking, authentication, or security purposes
- Evaluates potential cookie-related security vulnerabilities
- Provides actionable recommendations for securing cookies
- Saves results in a JSON file for further analysis

**Usage:**

```sh
python scan-cookies.py <URL>
```

Example:

```sh
python scan-cookies.py https://www.mydomain.com
```

### 3. HTTP Security Headers Analyzer

**Tool:** `scan-headers.sh`\
**Description:** This Bash script analyzes HTTP response headers to identify missing or misconfigured security headers.

#### Features

- Checks for critical security headers:
  - `Content-Security-Policy`
  - `X-Frame-Options`
  - `X-Content-Type-Options`
  - `Strict-Transport-Security`
  - `Referrer-Policy`
  - `X-XSS-Protection`
  - `Expect-CT`
- Highlights missing headers that should be implemented for better security
- Provides a direct link to SecurityHeaders.com for further analysis
- Color-coded output for quick risk assessment

**Usage:**

```sh
./scan-headers.sh <URL>
```

Example:

```sh
./scan-headers.sh https://www.mydomain.com
```

## Requirements

To run the Python-based tools, install dependencies with:

```sh
pip install -r requirements.txt
```

**Required Packages:**

- `selenium` - For browser automation in cookie scanning
- `tabulate` - For table formatting in reports
- `webdriver-manager` - For managing Chrome WebDriver

Additionally, `scan-ssl-tls.py` requires `sslscan`, which can be installed on Linux/macOS via:

```sh
brew install sslscan      # macOS (Homebrew)
sudo apt install sslscan  # Debian/Ubuntu
```

## Output Format

Each script provides structured output:

- **scan-ssl-tls.py**: Displays SSL/TLS details in terminal with emoji indicators for security levels and suggests improvements.
- **scan-cookies.py**: Prints analysis in terminal and saves detailed results as `cookies_analysis.json`.
- **scan-headers.sh**: Displays color-coded results in terminal and provides a link to SecurityHeaders.com for further analysis.

## Integration with Security Workflows

These tools can be integrated into:

- CI/CD pipelines for automated security testing
- Development workflows for pre-deployment checks
- Security audit processes for compliance verification
- Continuous monitoring systems for detecting security regressions

## License

This project is licensed under the MIT License. See the [LICENSE](../LICENSE) file for details.

## Contributions

Contributions and improvements are welcome! Please fork the repository and submit pull requests for enhancements or additional security scanning scripts.

## Author

Developed by **Doug Hitchen** ([GitHub](https://github.com/drhitchen)).
