#!/bin/bash

# Website Security Headers Analyzer
# This script analyzes security headers from a website and provides output similar to shcheck.py
# It also includes a direct link to SecurityHeaders.com for further analysis
# Usage: ./analyze-headers.sh https://example.com

# Check if a URL was provided
if [ $# -eq 0 ]; then
    echo -e "\n❌ Error: No URL provided"
    echo "Usage: $0 https://example.com"
    exit 1
fi

URL=$1

# Validate URL format
if [[ ! $URL =~ ^https?:// ]]; then
    echo -e "\n⚠️  Warning: URL should start with http:// or https://"
    URL="https://$URL"
    echo -e "🔄 Proceeding with: $URL"
fi

# Extract domain for SecurityHeaders.com link
DOMAIN=$(echo "$URL" | awk -F[/:] '{print $4}')
SECURITY_HEADERS_URL="https://securityheaders.com/?q=$DOMAIN&followRedirects=on"

# ANSI color codes
RED='\033[0;31m'      # High Risk/Missing
GREEN='\033[0;32m'    # Low Risk/Good
YELLOW='\033[0;33m'   # Warning/Info
BLUE='\033[0;34m'     # Informational
BOLD='\033[1m'        # Bold
NC='\033[0m'          # No Color

# Print header
echo -e "\n🔍 Analyzing headers for: ${BLUE}$URL${NC}"

# Use curl to fetch headers with effective URL
HEADERS=$(curl -sLI "$URL" -A "Mozilla/5.0 SecurityHeaderScanner" --max-time 10)
EFFECTIVE_URL=$(curl -sL "$URL" -A "Mozilla/5.0 SecurityHeaderScanner" --max-time 10 -o /dev/null -w '%{url_effective}')

if [ -z "$HEADERS" ]; then
    echo -e "\n❌ Error: Failed to retrieve headers from $URL"
    exit 1
fi

echo -e "🔗 Effective URL: ${BLUE}$EFFECTIVE_URL${NC}\n"

# Headers to check
HEADERS_TO_CHECK=(
    "Content-Security-Policy"
    "X-Frame-Options"
    "X-Content-Type-Options"
    "Strict-Transport-Security"
    "Referrer-Policy"
    "X-XSS-Protection"
    "Expect-CT"
)

# Arrays to store results
PRESENT_HEADERS=()
PRESENT_VALUES=()
MISSING_HEADERS=()

# Check each security header
for header_name in "${HEADERS_TO_CHECK[@]}"; do
    header_value=$(echo "$HEADERS" | grep -i "^$header_name:" | sed "s/^$header_name: //i" | tr -d '\r\n' | tr -s ' ' | sed 's/^ *//' | sed 's/ *$//')
    
    if [ -z "$header_value" ]; then
        MISSING_HEADERS+=("$header_name")
    else
        PRESENT_HEADERS+=("$header_name")
        PRESENT_VALUES+=("$header_value")
    fi
done

# Display present headers
echo -e "${NC}${BOLD}SECURITY HEADERS PRESENT:${NC}"
for i in "${!PRESENT_HEADERS[@]}"; do
    echo -e "   ✅ ${PRESENT_HEADERS[$i]}: ${PRESENT_VALUES[$i]}"
done

# Then display missing headers
echo -e "\n${NC}${BOLD}SECURITY HEADERS MISSING:${NC}"
for header_name in "${MISSING_HEADERS[@]}"; do
    echo -e "   ❌ $header_name"
done

echo -e "\n📌 For a full report, visit: $SECURITY_HEADERS_URL\n"
