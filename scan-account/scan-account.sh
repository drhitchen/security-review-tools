#!/bin/bash
# scan-account.sh - AWS security scan using Prowler and ScoutSuite

# Increase file descriptor limit to prevent "Too many open files" errors
ulimit -Sn 1000

###############################################################################
# Usage & Argument Parsing
###############################################################################

usage() {
    cat <<EOF
Usage: $0 [-a aws_account] [-p aws_profile] [-c compliance] [-o output_directory] [-t tool]
  -a aws_account   AWS account number (or set AWS_ACCOUNT in .env)
  -p aws_profile   AWS CLI profile (default: default)
  -c compliance    Prowler compliance framework (default: cis_1.5_aws)
  -o output_dir    Base output directory (default: ./output)
  -t tool          Which scan to run: 'prowler', 'scout', or 'both' (default: both)
EOF
    exit 1
}

while getopts "a:p:c:o:t:" opt; do
    case $opt in
        a) account_opt="$OPTARG" ;;
        p) profile_opt="$OPTARG" ;;
        c) compliance_opt="$OPTARG" ;;
        o) output_opt="$OPTARG" ;;
        t) tool_opt="$OPTARG" ;;
        *) usage ;;
    esac
done

###############################################################################
# Environment Setup
###############################################################################

# Load environment variables from .env if available
if [ -f ".env" ]; then
    echo "Loading settings from .env"
    # shellcheck disable=SC1091
    source ".env"
fi

AWS_ACCOUNT="${account_opt:-$AWS_ACCOUNT}"
if [ -z "$AWS_ACCOUNT" ]; then
    echo "Error: AWS account not specified."
    usage
fi

AWS_PROFILE="${profile_opt:-${AWS_PROFILE:-default}}"
COMPLIANCE="${compliance_opt:-${COMPLIANCE:-cis_1.5_aws}}"

# We'll store results under output/account-scans/<account_id> by default
OUTPUT_ROOT="${output_opt:-$(pwd)/output}/account-scans"
ACCOUNT_DIR="$OUTPUT_ROOT/$AWS_ACCOUNT"
SCANS_DIR="$ACCOUNT_DIR/scans"
SUMMARIES_DIR="$ACCOUNT_DIR/summaries"
LOGS_DIR="$ACCOUNT_DIR/logs"

# Create directory structure
mkdir -p "$SCANS_DIR/prowler" "$SCANS_DIR/scoutsuite" "$SUMMARIES_DIR" "$LOGS_DIR"

TOOL_SELECTION="${tool_opt:-both}"  # Valid values: prowler, scout, both

TIMESTAMP=$(date +%Y%m%d%H%M%S)
MANIFEST="$LOGS_DIR/scan_manifest_${TIMESTAMP}.log"

###############################################################################
# Logging Function
###############################################################################

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$MANIFEST"
}

###############################################################################
# Tool Execution Functions
###############################################################################

run_prowler() {
    # Store all Prowler output in $SCANS_DIR/prowler
    local prowler_dir="$SCANS_DIR/prowler"
    local cmd="prowler aws --compliance $COMPLIANCE --profile $AWS_PROFILE -o $prowler_dir"

    log "Running Prowler scan with command: $cmd"
    eval "$cmd"
    # If Prowler generates multiple files (CSV, HTML, JSON) they should appear in that folder
}

run_scoutsuite() {
    # Store ScoutSuite output in $SCANS_DIR/scoutsuite
    local scout_dir="$SCANS_DIR/scoutsuite"
    local cmd="scout aws --profile $AWS_PROFILE --no-browser --report-dir $scout_dir --report-name ${AWS_ACCOUNT}.scoutsuite"

    log "Running ScoutSuite scan with command: $cmd"
    eval "$cmd"
    # Typically creates HTML and a results folder under $scout_dir
}

###############################################################################
# Main Execution Block
###############################################################################

log "=== AWS Account Scan Started ==="
log "Parameters:"
log "  AWS Account      : $AWS_ACCOUNT"
log "  AWS Profile      : $AWS_PROFILE"
log "  Compliance Frame : $COMPLIANCE"
log "  Output Directory : $OUTPUT_ROOT"
log "  Tools to run     : $TOOL_SELECTION"

# Role assumption: if AWS_ROLE is set, assume it
if [ -n "$AWS_ROLE" ]; then
    ROLE_SESSION="${AWS_ROLE_SESSION_NAME:-scanAccountSession}"
    log "Attempting to assume role: $AWS_ROLE with session name: $ROLE_SESSION"
    credentials=$(aws --profile "$AWS_PROFILE" sts assume-role \
        --role-arn "$AWS_ROLE" \
        --role-session-name "$ROLE_SESSION" \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
        --output text 2>&1)
    if [ $? -ne 0 ]; then
        log "Error assuming role: $credentials"
        exit 1
    fi
    export AWS_ACCESS_KEY_ID=$(echo $credentials | awk '{print $1}')
    export AWS_SECRET_ACCESS_KEY=$(echo $credentials | awk '{print $2}')
    export AWS_SESSION_TOKEN=$(echo $credentials | awk '{print $3}')
    log "Assumed role successfully. AWS_ACCESS_KEY_ID updated."
fi

# Ensure required commands are available.
command -v prowler >/dev/null 2>&1 || { log "Error: prowler command not found."; exit 1; }
command -v scout >/dev/null 2>&1 || { log "Error: scout command not found."; exit 1; }

# Determine which tools to run
SUMMARY="=== Scan Summary ===\n"
if [[ "$TOOL_SELECTION" == "prowler" || "$TOOL_SELECTION" == "both" ]]; then
    run_prowler
    SUMMARY+="Prowler results: $SCANS_DIR/prowler\n"
fi
if [[ "$TOOL_SELECTION" == "scoutsuite" || "$TOOL_SELECTION" == "both" ]]; then
    run_scoutsuite
    SUMMARY+="ScoutSuite results: $SCANS_DIR/scoutsuite\n"
fi

###############################################################################
# (Optional) Summaries or Post-Processing
###############################################################################
# Example: If you have a prowler_summary.sh or scout_summary.sh, you could run them
# and place outputs in $SUMMARIES_DIR. For example:

# if [ -f "$SCANS_DIR/prowler/prowler-output-...ocsf.json" ]; then
#     ./prowler_summary.sh "$SCANS_DIR/prowler/prowler-output-...ocsf.json"
#     mv prowler_summary_outputs* "$SUMMARIES_DIR/"
# fi

log "$SUMMARY"
log "=== Scanning Complete ==="

log "Raw scans in: $SCANS_DIR"
log "Summaries in: $SUMMARIES_DIR (if generated)"
log "Logs in: $LOGS_DIR"
log "Manifest file: $MANIFEST"
