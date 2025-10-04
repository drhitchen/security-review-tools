#!/bin/bash
set -euo pipefail

###############################################################################
# Parse Command-Line Arguments
###############################################################################
while getopts "r:o:m:" opt; do
  case "$opt" in
    r) REPO_FOLDER="$OPTARG" ;;
    o) OUTPUT_ROOT="$OPTARG" ;;
    m) MODEL="$OPTARG" ;;
    *) echo "Usage: $0 -r repo_folder [-o output_root] [-m model]"; exit 1 ;;
  esac
done

if [[ -z "${REPO_FOLDER:-}" ]]; then
  echo "Error: Repository folder is required (-r)."
  exit 1
fi

# Remove trailing slash for consistency
REPO_FOLDER="${REPO_FOLDER%/}"
REPO_BASENAME="$(basename "$REPO_FOLDER")"

if [[ -z "${OUTPUT_ROOT:-}" ]]; then
  OUTPUT_ROOT="$(pwd)/output/code-scans/${REPO_BASENAME}"
fi

###############################################################################
# Define Directories & Logging
###############################################################################
SCANS_DIR="$OUTPUT_ROOT/scans"
SUMMARIES_DIR="$OUTPUT_ROOT/summaries"
LOGS_DIR="$OUTPUT_ROOT/logs"
REPORTS_DIR="$OUTPUT_ROOT/reports"

# Create directories
mkdir -p "$SCANS_DIR" "$SUMMARIES_DIR" "$LOGS_DIR" "$REPORTS_DIR"

# Generate timestamp and manifest file
TIMESTAMP=$(date +%Y%m%d%H%M%S)
MANIFEST="$LOGS_DIR/fabric_reports_manifest_${TIMESTAMP}.log"

# Logging function: logs messages with a timestamp to console and manifest.
log() {
  echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$MANIFEST"
}

log "=== Fabric Summary Started ==="
log "Parameters:"
log "  Repository Folder: $REPO_FOLDER"
log "  Repository Basename: $REPO_BASENAME"
log "  Output Root: $OUTPUT_ROOT"
log "  SCANS_DIR: $SCANS_DIR"
log "  SUMMARIES_DIR: $SUMMARIES_DIR"
log "  LOGS_DIR: $LOGS_DIR"
log "  REPORTS_DIR: $REPORTS_DIR"
if [[ -n "${MODEL:-}" ]]; then
  log "  Model Override : $MODEL"
else
  log "  Model Override : (default)"
fi

###############################################################################
# Create LLM Prompt from Scan Summaries (code2prompt)
###############################################################################
log "Executing: code2prompt --tokens \"$SUMMARIES_DIR\""
code2prompt --tokens "$SUMMARIES_DIR"
log "code2prompt execution completed."

###############################################################################
# Run Fabric Summarization Commands
###############################################################################
# Define prompts and output file names, now targeting REPORTS_DIR
PROMPT1="Summarize these code scan summaries. Show source, line #, CVE/CWE with description where available."
OUTPUT1="$REPORTS_DIR/fabric_summary_1_${TIMESTAMP}.md"
log "Executing Fabric summarization command 1: pbpaste | fabric \"$PROMPT1\" ${MODEL:+--model \"$MODEL\"} --output=\"$OUTPUT1\""
pbpaste | fabric "$PROMPT1" ${MODEL:+--model "$MODEL"} --output="$OUTPUT1"
log "Fabric summarization command 1 completed. Output saved to $OUTPUT1"

# Sleep a while to avoid API rate limits
sleep 60s

PROMPT2="Summarize these code scan summaries. Show source, line #, CVE/CWE with description where available. Include summary tables."
OUTPUT2="$REPORTS_DIR/fabric_summary_2_${TIMESTAMP}.md"
log "Executing Fabric summarization command 2: pbpaste | fabric \"$PROMPT2\" ${MODEL:+--model \"$MODEL\"} --output=\"$OUTPUT2\""
pbpaste | fabric "$PROMPT2" ${MODEL:+--model "$MODEL"} --output="$OUTPUT2"
log "Fabric summarization command 2 completed. Output saved to $OUTPUT2"

# Sleep a while to avoid API rate limits
sleep 60s

PROMPT3="Analyze these code scan summaries. Recommend security controls and guardrails for secure production use."
OUTPUT3="$REPORTS_DIR/fabric_summary_requirements_${TIMESTAMP}.md"
log "Executing Fabric summarization command 3: pbpaste | fabric \"$PROMPT3\" ${MODEL:+--model \"$MODEL\"} --output=\"$OUTPUT3\""
pbpaste | fabric "$PROMPT3" ${MODEL:+--model "$MODEL"} --output="$OUTPUT3"
log "Fabric summarization command 3 completed. Output saved to $OUTPUT3"

###############################################################################
# Completion
###############################################################################
log "All Fabric summarization prompts completed."
log "Reports are in: $REPORTS_DIR"
log "Logs are in: $LOGS_DIR"
log "=== Fabric Summary Complete ==="

echo "All Fabric summarization prompts completed."
echo "Reports are in: $REPORTS_DIR"
echo "Logs are in: $LOGS_DIR"
