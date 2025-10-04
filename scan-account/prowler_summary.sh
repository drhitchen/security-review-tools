#!/bin/bash
# prowler_summary.sh - Summarize Prowler .ocsf.json results, storing outputs in
# the same structured directories used by scan-account.sh.

###############################################################################
# Usage & Argument Parsing
###############################################################################

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  -f <prowler_ocsf.json>  Path to the Prowler .ocsf.json file (default: auto-find latest)
  -a <aws_account>         AWS Account ID (optional; helps place files in account-scans/<AWS_ACCOUNT>/summaries)
  -o <base_output_dir>     Base output directory (default: ./output)

If -a is provided, output goes under:
  <base_output_dir>/account-scans/<AWS_ACCOUNT>/summaries
and logs under:
  <base_output_dir>/account-scans/<AWS_ACCOUNT>/logs

If -a is NOT provided, we fallback to:
  <base_output_dir>/summaries
and
  <base_output_dir>/logs
EOF
    exit 1
}

PROWLER_FILE=""
AWS_ACCOUNT=""
OUTPUT_BASE="./output"

while getopts "f:a:o:" opt; do
    case $opt in
        f) PROWLER_FILE="$OPTARG" ;;
        a) AWS_ACCOUNT="$OPTARG" ;;
        o) OUTPUT_BASE="$OPTARG" ;;
        *) usage ;;
    esac
done

###############################################################################
# Environment Setup
###############################################################################

timestamp=$(date +%Y%m%d%H%M%S)

if [ -n "$AWS_ACCOUNT" ]; then
  # We have an account. Keep consistent with account-scans folder structure
  ACCOUNT_DIR="$OUTPUT_BASE/account-scans/$AWS_ACCOUNT"
  SUMMARIES_DIR="$ACCOUNT_DIR/summaries"
  LOGS_DIR="$ACCOUNT_DIR/logs"
else
  # Fallback if no account is specified
  SUMMARIES_DIR="$OUTPUT_BASE/summaries"
  LOGS_DIR="$OUTPUT_BASE/logs"
fi

mkdir -p "$SUMMARIES_DIR" "$LOGS_DIR"

MANIFEST="$LOGS_DIR/prowler_manifest_${timestamp}.log"

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$MANIFEST"
}

###############################################################################
# Auto-Find File If Not Provided
###############################################################################

# If no file was provided, try to find the newest prowler .ocsf.json
get_latest_prowler_report() {
    local latest_file
    latest_file=$(find . -type f -name "prowler-output-*.ocsf.json" 2>/dev/null \
        | xargs ls -t 2>/dev/null \
        | head -n 1)
    echo "$latest_file"
}

if [[ -z "$PROWLER_FILE" ]]; then
    PROWLER_FILE="$(get_latest_prowler_report)"
fi

if [[ -z "$PROWLER_FILE" || ! -f "$PROWLER_FILE" ]]; then
    log "❌ No valid Prowler .ocsf.json file found!"
    exit 1
fi

###############################################################################
# Main Summarization
###############################################################################

log "=== Prowler Summary ==="
log "Using Prowler file: $PROWLER_FILE"

# 1) Pass/Fail/Manual
SUMMARY_FILE="$SUMMARIES_DIR/prowler_pass_fail_summary_${timestamp}.txt"
jq -r '.[] | .status_code' "$PROWLER_FILE" | sort | uniq -c | tee "$SUMMARY_FILE"
log "Pass/Fail summary written to: $SUMMARY_FILE"

# 2) Findings by Severity
SEVERITY_FILE="$SUMMARIES_DIR/prowler_severity_summary_${timestamp}.txt"
jq -r '.[] | select(.status_code == "FAIL") | .severity' "$PROWLER_FILE" | sort | uniq -c | tee "$SEVERITY_FILE"
log "Severity summary written to: $SEVERITY_FILE"

# 3) Regional Summary
REGION_FILE="$SUMMARIES_DIR/prowler_regional_summary_${timestamp}.txt"
{
    echo -e "Region\tPASS\tFAIL\tMANUAL"
    jq -r -f /dev/stdin "$PROWLER_FILE" <<'EOF'
group_by(.cloud.region) |
map({
  region: .[0].cloud.region,
  pass: ([.[] | select(.status_code=="PASS")] | length),
  fail: ([.[] | select(.status_code=="FAIL")] | length),
  manual: ([.[] | select(.status_code=="MANUAL")] | length)
}) |
sort_by(.region) |
.[] |
"\(.region)\t\(.pass)\t\(.fail)\t\(.manual)"
EOF
} | column -t -s $'\t' | tee "$REGION_FILE"
log "Regional summary written to: $REGION_FILE"

log "=== Prowler Summary Complete ==="
log "Summaries in: $SUMMARIES_DIR"
log "Logs in: $LOGS_DIR"
log "Manifest file: $MANIFEST"
