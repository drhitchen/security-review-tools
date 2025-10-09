#!/bin/bash
# bearer_summary.sh - Summarize one or more Bearer scan results (JSON format).
# Supports both "security" and "privacy" scans in a single pass.

###############################################################################
# Usage & Argument Parsing
###############################################################################

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  -f <bearer_json_file>  Path to a Bearer JSON file (optional).
                         If omitted but -r is provided, we look for *all*
                         <repo_name>.bearer_*.json in scans/ and process them.
  -r <repo_name>         Repository name (will place outputs under code-scans/<repo_name>).
  -o <base_dir>          Base output directory (default: ./output/code-scans/<repo_name>).

Examples:
  # Summarize *all* Bearer JSONs for "myrepo" in scans/myrepo.bearer_*.json:
  ./bearer_summary.sh -r myrepo

  # Summarize a specific "security" JSON:
  ./bearer_summary.sh -f ./output/code-scans/myrepo/scans/myrepo.bearer_security.json -r myrepo

  # Summarize a "privacy" JSON with a custom base path:
  ./bearer_summary.sh -f my.bearer_privacy.json -r myrepo -o /custom/path
EOF
    exit 1
}

BEARER_FILE=""
REPO_NAME=""
OUTPUT_BASE=""

while getopts "f:r:o:" opt; do
    case $opt in
        f) BEARER_FILE="$OPTARG" ;;
        r) REPO_NAME="$OPTARG" ;;
        o) OUTPUT_BASE="$OPTARG" ;;
        *) usage ;;
    esac
done

###############################################################################
# Environment Setup
###############################################################################

timestamp=$(date +%Y%m%d%H%M%S)

# Simple output structure: scans/, summaries/, logs/ directly under output/
LOCAL_OUTPUT="${OUTPUT_BASE:-./output}"
SCANS_DIR="$LOCAL_OUTPUT/scans"
SUMMARIES_DIR="$LOCAL_OUTPUT/summaries" 
LOGS_DIR="$LOCAL_OUTPUT/logs"

mkdir -p "$SUMMARIES_DIR" "$LOGS_DIR"

MANIFEST="$LOGS_DIR/bearer_summary_manifest_${timestamp}.log"

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$MANIFEST"
}

###############################################################################
# Gather Files To Process
###############################################################################

files_to_process=()

if [ -n "$BEARER_FILE" ]; then
    # If user provided -f, just process that single file
    files_to_process+=("$BEARER_FILE")
elif [ -n "$REPO_NAME" ]; then
    # No -f, but we have a repo name => auto-discover all matching JSON  
    # First, try with the basename of the repo path (in case it's a full path)
    REPO_BASENAME=$(basename "$REPO_NAME")
    
    # Try finding with full repo name first, sort by modification time (newest first)
    while IFS= read -r line; do
        [ -n "$line" ] && files_to_process+=("$line")
    done < <( find "$SCANS_DIR" -maxdepth 1 -type f -name "${REPO_NAME}.bearer_*.json" -printf '%T@ %p\n' 2>/dev/null \
              | sort -rn | cut -d' ' -f2- || true )
    
    # If no files found and repo name looks like a path, try with just the basename
    if [ ${#files_to_process[@]} -eq 0 ] && [ "$REPO_NAME" != "$REPO_BASENAME" ]; then
        while IFS= read -r line; do
            [ -n "$line" ] && files_to_process+=("$line")
        done < <( find "$SCANS_DIR" -maxdepth 1 -type f -name "${REPO_BASENAME}.bearer_*.json" -printf '%T@ %p\n' 2>/dev/null \
                  | sort -rn | cut -d' ' -f2- || true )
    fi

    if [ ${#files_to_process[@]} -eq 0 ]; then
        log "No Bearer JSON found in $SCANS_DIR for '$REPO_NAME' (or '$REPO_BASENAME')"
        log "Looking for files matching: ${REPO_NAME}.bearer_*.json or ${REPO_BASENAME}.bearer_*.json"
        log "Available Bearer files: $(find "$SCANS_DIR" -maxdepth 1 -name "*.bearer_*.json" 2>/dev/null | head -5 | tr '\n' ' ')"
        log "Skipping Bearer summary - no matching files found."
        exit 0
    fi
else
    # Neither -f nor -r => can't auto-discover
    echo "Error: Must provide -f or use -r with known repo name."
    usage
fi

###############################################################################
# Summaries for Privacy vs Security
###############################################################################
# We remove the "repo name" from summary filenames by using fixed names like
# bearer_privacy_*, bearer_security_*, etc., appended with timestamps.

summarize_privacy() {
    local jsonFile="$1"
    local baseName
    baseName="$(basename "$jsonFile")"
    log "Detected Bearer Privacy => $baseName"

    # 1) Subject summary
    local PRIVACY_SUBJECT_FILE="$SUMMARIES_DIR/bearer_privacy_subject_summary_${timestamp}.txt"
    {
      echo -e "SUBJECT\tDATA_TYPE\tDETECTIONS\tCRIT/HIGH/MED/LOW"
      jq -r '
        .subjects[]?
        | [
            (.subject_name // "Unknown"),
            (.name // "Unknown"),
            (.detection_count|tostring),
            (
              "Crit=" + (.critical_risk_failure_count|tostring)
              + "/High=" + (.high_risk_failure_count|tostring)
              + "/Med=" + (.medium_risk_failure_count|tostring)
              + "/Low=" + (.low_risk_failure_count|tostring)
            )
          ]
        | @tsv
      ' "$jsonFile"
    } | column -t -s $'\t' > "$PRIVACY_SUBJECT_FILE"
    log "Privacy subject summary -> $PRIVACY_SUBJECT_FILE"

    # 2) Third-party summary
    local PRIVACY_TP_FILE="$SUMMARIES_DIR/bearer_privacy_thirdparty_summary_${timestamp}.txt"
    {
      echo -e "THIRD_PARTY\tDATA_TYPES\tCRIT/HIGH/MED/LOW"
      jq -r '
        .third_party[]?
        | [
            (.third_party // "Unknown"),
            (.data_types|join(",")),
            (
              "Crit=" + (.critical_risk_failure_count|tostring)
              + "/High=" + (.high_risk_failure_count|tostring)
              + "/Med=" + (.medium_risk_failure_count|tostring)
              + "/Low=" + (.low_risk_failure_count|tostring)
            )
          ]
        | @tsv
      ' "$jsonFile"
    } | column -t -s $'\t' > "$PRIVACY_TP_FILE"
    log "Privacy third-party summary -> $PRIVACY_TP_FILE"

    # 3) Grand total of detections
    local GRAND_TOTAL_FILE="$SUMMARIES_DIR/bearer_privacy_grand_total_${timestamp}.txt"
    local totalDetections
    totalDetections=$(jq '[.subjects[]?.detection_count] | add' "$jsonFile" 2>/dev/null)
    [ -z "$totalDetections" ] && totalDetections="0"

    echo "Total Data Detections (all subjects): $totalDetections" > "$GRAND_TOTAL_FILE"
    log "Grand total -> $GRAND_TOTAL_FILE"
}

summarize_security() {
    local jsonFile="$1"
    local baseName
    baseName="$(basename "$jsonFile")"
    log "Detected Bearer Security => $baseName"

    # 1) Severity counts
    local SECURITY_SEVERITY_FILE="$SUMMARIES_DIR/bearer_security_severity_counts_${timestamp}.txt"
    {
      echo -e "SEVERITY\tCOUNT"
      for sev in critical high medium low; do
          local count
          count=$(jq -r --arg s "$sev" '.[$s] | length' "$jsonFile" 2>/dev/null)
          [[ "$count" =~ ^[0-9]+$ ]] || count=0
          echo -e "${sev}\t${count}"
      done
    } | column -t > "$SECURITY_SEVERITY_FILE"
    log "Security severity count -> $SECURITY_SEVERITY_FILE"

    # 2) Detailed CSV
    local SECURITY_DETAILED_FILE="$SUMMARIES_DIR/bearer_security_detailed_${timestamp}.csv"
    {
      echo "severity,id,title,file_line,description"
      for sev in critical high medium low; do
          local exists
          exists=$(jq -r --arg s "$sev" 'has($s)' "$jsonFile" 2>/dev/null)
          [ "$exists" = "true" ] || continue

          jq -r --arg s "$sev" '
            .[$s][]?
            | [
                $s,
                (.id // "unknown"),
                (.title // "Untitled" | gsub(",";" ")),
                ((.filename // "unknown") + ":" + (.line_number|tostring)),
                ( .description // "No description"
                  | gsub("[\n\r]"; " ")
                  | gsub(",";" ")
                )
              ]
            | @csv
          ' "$jsonFile"
      done
    } > "$SECURITY_DETAILED_FILE"
    log "Detailed CSV -> $SECURITY_DETAILED_FILE"

    # 3) Summarize by CWE
    local SECURITY_CWE_FILE="$SUMMARIES_DIR/bearer_security_cwe_summary_${timestamp}.txt"
    {
      echo "CWE_ID COUNT"
      # Gather cwe_ids from all severity arrays
      jq -r '
        [
          .critical[]?.cwe_ids[],
          .high[]?.cwe_ids[],
          .medium[]?.cwe_ids[],
          .low[]?.cwe_ids[]
        ]
      ' "$jsonFile" 2>/dev/null \
        | jq -r '
          group_by(.) | map({cwe: .[0], count: length})
          | sort_by(.count) | reverse
          | .[]
          | "\(.cwe) \(.count)"
        ' 2>/dev/null
    } | column -t > "$SECURITY_CWE_FILE"
    log "CWE summary -> $SECURITY_CWE_FILE"
}

summarize_one_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        log "WARNING: '$file' not found, skipping."
        return
    fi

    # Check keys to see if it has 'privacy' structure or 'security' structure
    local hasPrivacy
    hasPrivacy=$(jq 'has("subjects") or has("third_party")' "$file" 2>/dev/null)
    local hasSecurity
    hasSecurity=$(jq 'has("critical") or has("high") or has("medium") or has("low")' "$file" 2>/dev/null)

    local isPrivacy=0
    local isSecurity=0
    [ "$hasPrivacy" = "true" ] && isPrivacy=1
    [ "$hasSecurity" = "true" ] && isSecurity=1

    if [ $isPrivacy -eq 0 ] && [ $isSecurity -eq 0 ]; then
        log "WARNING: '$file' has no recognized privacy/security keys. Summaries may be incomplete!"
    fi

    [ $isPrivacy -eq 1 ] && summarize_privacy "$file"
    [ $isSecurity -eq 1 ] && summarize_security "$file"
}

###############################################################################
# Main Execution
###############################################################################

log "=== Bearer Summary Started ==="
log "Files to process: ${files_to_process[*]}"
log "Summaries => $SUMMARIES_DIR"
log "Logs => $LOGS_DIR"

for f in "${files_to_process[@]}"; do
    summarize_one_file "$f"
done

log "=== Bearer Summary Complete ==="
log "Manifest: $MANIFEST"
