#!/bin/bash
# snyk_summary.sh - Summarize Snyk Code results (JSON or SARIF).
# If -r is specified, we place outputs under code-scans/<repo_name>.
# If no -f is provided, we auto-discover the newest *snyk.json or *snyk.sarif file.

###############################################################################
# Usage & Argument Parsing
###############################################################################

usage() {
    cat <<EOF
Usage: $0 [options]
  -f <snyk_file>   Path to a Snyk output file (.json or .sarif). Optional.
  -r <repo_name>   Repository name (for code-scans/<repo_name>/)
  -o <base_dir>    Base output directory (default: ./output/code-scans/<repo_name>)

If -f is not provided, we attempt to find the newest file matching:
  *snyk.json or *snyk.sarif

Examples:
  # Summarize a known Snyk JSON file:
  ./snyk_summary.sh -f ./output/code-scans/myrepo/scans/myrepo.snyk.json -r myrepo

  # Summarize a known Snyk SARIF file with custom base dir:
  ./snyk_summary.sh -f ./path/to/my.snyk.sarif -r myrepo -o /custom/output

  # Auto-discover Snyk file under code-scans/my-app/scans:
  ./snyk_summary.sh -r my-app
EOF
    exit 1
}

SNYK_FILE=""
REPO=""
OUTPUT_BASE=""
while getopts "f:r:o:" opt; do
    case $opt in
        f) SNYK_FILE="$OPTARG" ;;
        r) REPO="$OPTARG" ;;
        o) OUTPUT_BASE="$OPTARG" ;;
        *) usage ;;
    esac
done

###############################################################################
# Environment Setup
###############################################################################

timestamp=$(date +%Y%m%d%H%M%S)

if [ -n "$REPO" ]; then
    # Using flat directory structure
    local_output="${OUTPUT_BASE:-./output}"
    SCANS_DIR="$local_output/scans"
    SUMMARIES_DIR="$local_output/summaries"
    LOGS_DIR="$local_output/logs"
else
    # Fallback to top-level or current folder
    local_output="${OUTPUT_BASE:-./output}"
    SCANS_DIR="$(pwd)"
    SUMMARIES_DIR="$local_output"
    LOGS_DIR="$local_output"
fi

mkdir -p "$SUMMARIES_DIR" "$LOGS_DIR"
MANIFEST="$LOGS_DIR/snyk_summary_manifest_${timestamp}.log"

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$MANIFEST"
}

###############################################################################
# Auto-Discovery (if -f not given)
###############################################################################

find_latest_snyk_file() {
    local exts=("*snyk.json" "*.snyk.sarif" "*snyk.json" "*snyk.sarif")
    local best=""
    for pattern in "${exts[@]}"; do
        local candidate
        # Use ls -t for newest, head -n1
        candidate=$(ls -t "$SCANS_DIR"/$pattern 2>/dev/null | head -n1)
        if [ -n "$candidate" ]; then
            if [ -z "$best" ]; then
                best="$candidate"
            else
                # If candidate is newer than best, update best
                if [ "$candidate" -nt "$best" ]; then
                    best="$candidate"
                fi
            fi
        fi
    done
    echo "$best"
}

if [ -z "$SNYK_FILE" ]; then
    SNYK_FILE=$(find_latest_snyk_file)
fi

if [ -z "$SNYK_FILE" ] || [ ! -f "$SNYK_FILE" ]; then
    log "Error: No valid Snyk file found in $SCANS_DIR!"
    usage
fi

log "=== Snyk Summary Started ==="
log "Using file: $SNYK_FILE"
log "Summaries => $SUMMARIES_DIR"
log "Logs => $LOGS_DIR"

EXT="${SNYK_FILE##*.}"
if [[ "$EXT" =~ ^[Jj][Ss][Oo][Nn]$ ]]; then
    isJSON=1
    isSARIF=0
elif [[ "$EXT" =~ ^[Ss][Aa][Rr][Ii][Ff]$ ]]; then
    isJSON=0
    isSARIF=1
else
    log "Error: File must end with .json or .sarif"
    usage
fi

###############################################################################
# Summaries for JSON
###############################################################################
if [ $isJSON -eq 1 ]; then
    # Typical Snyk Code JSON might have a structure like:
    # {
    #   "summary": { "issues": { "critical": 0, "high":1, "medium":3, "low":2 }},
    #   "reportVersion": "vX.Y.Z",
    #   "results": [...]  # array of issues or similar
    # }
    # This can vary by product. Adjust queries if your structure differs.

    SNYK_JSON="$SNYK_FILE"

    SNYK_OVERVIEW="$SUMMARIES_DIR/snyk_overview_${timestamp}.txt"
    SNYK_CSV="$SUMMARIES_DIR/snyk_detailed_${timestamp}.csv"

    # 1) Total issues from some array, e.g., .results
    total_issues=$(jq '[.results[]?] | length' "$SNYK_JSON" 2>/dev/null)
    [ -z "$total_issues" ] && total_issues=0

    # 2) Severity distribution example: .summary.issues
    # For instance, you might do:
    # .summary.issues => { "critical": N, "high": N, "medium": N, "low": N }
    # We'll store that in JSON form:
    sev_dist_json=$(jq -r '
      if .summary.issues then
        {
          critical: .summary.issues.critical // 0,
          high: .summary.issues.high // 0,
          medium: .summary.issues.medium // 0,
          low: .summary.issues.low // 0
        }
      else
        { note: "No .summary.issues structure found" }
      end
    ' "$SNYK_JSON" 2>/dev/null)

    # 3) Possibly we want a short listing of the rules or issues from .results
    # The details can vary. We'll do an example for listing each result’s ruleId or other fields.

    {
      echo "=== Snyk JSON Overview ==="
      echo "File: $SNYK_JSON"
      echo "Total Issues (from .results[]): $total_issues"
      echo ""
      echo "=== Severity Distribution (from .summary.issues) ==="
      echo "$sev_dist_json" | jq .
    } > "$SNYK_OVERVIEW"

    log "Short overview -> $SNYK_OVERVIEW"

    # 4) Detailed CSV: we’ll attempt to gather a rule ID, file path, line range, severity, message, etc.
    # Because the exact structure can vary widely, adapt accordingly.
    # We’ll guess some typical fields:
    echo "rule_id,file_path,severity,line,message" > "$SNYK_CSV"
    jq -r '
      .results[]?
      | [
          (.rule?.id // "N/A"),
          (.location?.path // "N/A"),
          (.issueData?.severity // .severity // "N/A"),
          ((.location?.positions?.begin?.line|tostring) // "N/A"),
          # Try fallback for message
          (.issueData?.title // .message // "No message" | gsub("[,\n]"; " "))
        ]
      | @csv
    ' "$SNYK_JSON" >> "$SNYK_CSV" 2>/dev/null || {
        log "Warning: Could not parse JSON for a detailed CSV as expected."
    }

    log "Detailed CSV -> $SNYK_CSV"

###############################################################################
# Summaries for SARIF
###############################################################################
elif [ $isSARIF -eq 1 ]; then
    # Snyk SARIF often has .runs[].results[] each with:
    #   .ruleId
    #   .level => "error"|"warning"|"note"
    #   .message.text
    #   .locations[].physicalLocation.artifactLocation.uri
    #   .locations[].physicalLocation.region.startLine, .endLine
    # We'll produce an overview plus a CSV

    SNYK_SARIF="$SNYK_FILE"

    SNYK_OVERVIEW="$SUMMARIES_DIR/snyk_overview_${timestamp}.txt"
    SNYK_CSV="$SUMMARIES_DIR/snyk_detailed_${timestamp}.csv"

    total_findings=$(jq '[.runs[].results[]?] | length' "$SNYK_SARIF" 2>/dev/null)
    [ -z "$total_findings" ] && total_findings=0

    # Summarize by severity => .level
    # example: .runs[].results[].level => "error","warning","note"
    sev_dist=$(jq -r '
      [ .runs[].results[]? | {severity: .level} ]
      | group_by(.severity)
      | map({severity: .[0].severity, count: length})
    ' "$SNYK_SARIF" 2>/dev/null)

    # Summarize findings per rule ID
    top_rules=$(jq -r '
      [ .runs[].results[]? | {rule_id: .ruleId} ]
      | group_by(.rule_id)
      | map({rule: .[0].rule_id, count: length})
      | sort_by(.count) | reverse
    ' "$SNYK_SARIF" 2>/dev/null)

    {
      echo "=== Snyk SARIF Overview ==="
      echo "File: $SNYK_SARIF"
      echo "Total Findings: $total_findings"
      echo ""
      echo "=== Severity Distribution (by .level) ==="
      if [ -n "$sev_dist" ]; then
          echo "$sev_dist" | jq -r '.[] | "Severity: \(.severity), Count: \(.count)"'
      else
          echo "No severity data found."
      fi
      echo ""
      echo "=== Top Rules (by ruleId) ==="
      if [ -n "$top_rules" ]; then
          echo "$top_rules" | jq -r '
            .[] | "Rule: \(.rule), Count: \(.count)"
          ' | head -n 10
      else
          echo "No rule data found."
      fi
    } > "$SNYK_OVERVIEW"

    log "Short overview -> $SNYK_OVERVIEW"

    # Detailed CSV
    echo "rule_id,file_path,start_line,end_line,severity,message" > "$SNYK_CSV"
    jq -r '
      .runs[]?
      | .results[]?
      | [
          (.ruleId // "N/A"),
          (.locations[0]?.physicalLocation?.artifactLocation?.uri // "N/A"),
          ((.locations[0]?.physicalLocation?.region?.startLine|tostring) // "N/A"),
          ((.locations[0]?.physicalLocation?.region?.endLine|tostring) // "N/A"),
          (.level // "N/A"),
          (.message?.text // "No message" | gsub("[,\n]"; " "))
        ]
      | @csv
    ' "$SNYK_SARIF" >> "$SNYK_CSV" 2>/dev/null || {
        log "Warning: Could not parse SARIF for CSV as expected."
    }

    log "Detailed CSV -> $SNYK_CSV"
fi

log "=== Snyk Summary Complete ==="
log "Manifest: $MANIFEST"
