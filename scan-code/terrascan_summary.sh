#!/bin/bash
# terrascan_summary.sh - Summarize Terrascan results

usage() {
    cat <<EOF
Usage: $0 [options]
  -f <terrascan_text_file>   Path to Terrascan .txt
  -j <terrascan_json_file>   Path to Terrascan .json
  -r <repo_name>             Repo name for code-scans/<repo_name>/
  -o <base_dir>              Base output dir (default: ./output/code-scans/<repo_name>)
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

TIMESTAMP=$(date +%Y%m%d%H%M%S)

if [ -n "$REPO" ]; then
    local_output="${OUTPUT_BASE:-./output}/code-scans/$REPO"
    SUMMARIES_DIR="$local_output/summaries"
    LOGS_DIR="$local_output/logs"
else
    local_output="${OUTPUT_BASE:-./output}"
    SUMMARIES_DIR="$local_output"
    LOGS_DIR="$local_output"
fi

mkdir -p "$SUMMARIES_DIR" "$LOGS_DIR"
MANIFEST="$LOGS_DIR/terrascan_summary_manifest_${TIMESTAMP}.log"

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$MANIFEST"
}

log "=== Terrascan Summary Started ==="
log "Text file : $TXT_FILE"
log "JSON file : $JSON_FILE"
log "Summaries in: $SUMMARIES_DIR"
log "Logs in: $LOGS_DIR"

if [ -f "$TXT_FILE" ]; then
    TERRA_TXT_SUMMARY="$SUMMARIES_DIR/terrascan_scan_summary_${TIMESTAMP}.txt"
    grep -A20 'Scan Summary' "$TXT_FILE" > "$TERRA_TXT_SUMMARY"
    log "Terrascan text summary -> $TERRA_TXT_SUMMARY"
fi

if [ -f "$JSON_FILE" ]; then
    TERRA_JSON_SUMMARY="$SUMMARIES_DIR/terrascan_json_summary_${TIMESTAMP}.json"
    jq '[.results.violations[] | {rule_id: .rule_id}]
        | group_by(.rule_id)
        | map({rule: .[0].rule_id, count: length})' \
        "$JSON_FILE" \
        > "$TERRA_JSON_SUMMARY" 2>/dev/null || {
            log "Warning: Could not parse JSON as expected."
        }
    log "Terrascan JSON summary -> $TERRA_JSON_SUMMARY"
fi

log "=== Terrascan Summary Complete ==="
log "Manifest: $MANIFEST"
