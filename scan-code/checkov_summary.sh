#!/bin/bash
# checkov_summary.sh - Summarize Checkov scan results, placing outputs under
# code-scans/<repo_name>/summaries if -r is specified.

###############################################################################
# Usage & Argument Parsing
###############################################################################

usage() {
    cat <<EOF
Usage: $0 [options]
  -f <text_file>   Path to the Checkov .txt output (CLI format)
  -j <json_file>   Path to the Checkov .json output
  -r <repo_name>   Repository name (folder in code-scans/<repo_name>/)
  -o <base_dir>    Base output directory (default: ./output/code-scans/<repo_name>)

If -r is not provided, we fallback to placing summaries in ./output.

Examples:
  # Summarize existing files in code-scans/my-app, using the default location:
  ./checkov_summary.sh -f my-app.checkov.txt -j my-app.checkov.json -r my-app

  # Summarize logs in the current directory (no repo specified, fallback to ./output):
  ./checkov_summary.sh -f my.checkov.txt -j my.checkov.json

  # Let the script auto-find checkov.txt / checkov.json in code-scans/my-app/scans/:
  ./checkov_summary.sh -r my-app
EOF
    exit 1
}

TXT_FILE=""
JSON_FILE=""
REPO=""
OUTPUT_BASE=""
while getopts "f:j:r:o:" opt; do
    case $opt in
        f) TXT_FILE="$OPTARG" ;;
        j) JSON_FILE="$OPTARG" ;;
        r) REPO="$OPTARG" ;;
        o) OUTPUT_BASE="$OPTARG" ;;
        *) usage ;;
    esac
done

###############################################################################
# Environment Setup
###############################################################################

timestamp=$(date +%Y%m%d%H%M%S)

# If REPO is provided, we unify with the code-scans folder structure
if [ -n "$REPO" ]; then
    local_output="${OUTPUT_BASE:-./output}/code-scans/$REPO"
    SCANS_DIR="$local_output/scans"
    SUMMARIES_DIR="$local_output/summaries"
    LOGS_DIR="$local_output/logs"
else
    # Fallback to top-level
    local_output="${OUTPUT_BASE:-./output}"
    SCANS_DIR="$(pwd)"
    SUMMARIES_DIR="$local_output"
    LOGS_DIR="$local_output"
fi

mkdir -p "$SUMMARIES_DIR" "$LOGS_DIR"

MANIFEST="$LOGS_DIR/checkov_summary_manifest_${timestamp}.log"

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$MANIFEST"
}

###############################################################################
# Simple File Finder using ls -t
###############################################################################
find_latest_checkov_file() {
    local ext="$1"  # "txt" or "json"
    local search_dir="${SCANS_DIR}"

    # Use ls -t to sort by modification time descending, then take the first
    local latestFile
    latestFile=$(ls -t "$search_dir"/*checkov."$ext" 2>/dev/null | head -n1)
    echo "$latestFile"
}

# If user didn’t explicitly provide them, auto-find in $SCANS_DIR
if [ -z "$TXT_FILE" ]; then
    TXT_FILE=$(find_latest_checkov_file "txt")
fi
if [ -z "$JSON_FILE" ]; then
    JSON_FILE=$(find_latest_checkov_file "json")
fi

###############################################################################
# Summaries
###############################################################################

log "=== Checkov Summary Started ==="
log "Text file  : $TXT_FILE"
log "JSON file  : $JSON_FILE"
log "Summaries in: $SUMMARIES_DIR"
log "Logs in: $LOGS_DIR"

###############################################################################
# (1) Text-based summary
###############################################################################
if [ -f "$TXT_FILE" ]; then
    CHECKOV_FAIL_SUMMARY="$SUMMARIES_DIR/checkov_fail_summary_${timestamp}.txt"

    grep -B1 "FAILED" "$TXT_FILE" \
        | grep "Check" \
        | sort \
        | uniq -c \
        | sort -rn \
        > "$CHECKOV_FAIL_SUMMARY"

    log "Checkov FAIL summary (text) -> $CHECKOV_FAIL_SUMMARY"
else
    log "No Checkov text file found or specified."
fi

###############################################################################
# (2) JSON-based summary
###############################################################################
if [ -f "$JSON_FILE" ]; then

    # (a) High-level pass/fail per check_type
    CHECKOV_OVERALL_FILE="$SUMMARIES_DIR/checkov_overall_summary_${timestamp}.txt"
    jq -r '
      [
        .[]
        | "\(.check_type) => Passed: \(.summary.passed), Failed: \(.summary.failed), Skipped: \(.summary.skipped), Parsing Errors: \(.summary.parsing_errors), Resources: \(.summary.resource_count)"
      ]
      | .[]
    ' "$JSON_FILE" 2>/dev/null \
      > "$CHECKOV_OVERALL_FILE" || {
        log "Warning: Could not parse JSON for overall summary as expected."
      }
    log "Checkov overall summary (per check_type) -> $CHECKOV_OVERALL_FILE"

    # (b) Detailed CSV for each failed check
    CHECKOV_FAIL_CSV="$SUMMARIES_DIR/checkov_failed_checks_${timestamp}.csv"
    echo "check_type,check_id,bc_check_id,check_name,resource,file_path,line_range,guideline" \
      > "$CHECKOV_FAIL_CSV"

    jq -r '
      .[]
      | { check_type, failed_checks: .results.failed_checks }
      | [ .check_type, .failed_checks[]? ]
      | [
          (.[0] // "unknownCheckType"),
          (.[1].check_id // "N/A"),
          (.[1].bc_check_id // "N/A"),
          ((.[1].check_name // "N/A") | gsub("[,\n]"; " ")),
          (.[1].resource // "N/A"),
          (.[1].file_path // "N/A"),
          (((.[1].file_line_range // []) | map(tostring) | join("-")) // "N/A"),
          ((.[1].guideline // "N/A") | gsub("[,\n]"; " "))
        ]
      | @csv
    ' "$JSON_FILE" 2>/dev/null \
      >> "$CHECKOV_FAIL_CSV" || {
        log "Warning: Could not parse JSON for failed checks as expected."
      }

    log "Checkov failed checks CSV -> $CHECKOV_FAIL_CSV"

else
    log "No Checkov JSON file found or specified."
fi

log "=== Checkov Summary Complete ==="
log "Manifest: $MANIFEST"
