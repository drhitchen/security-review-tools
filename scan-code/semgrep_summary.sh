#!/bin/bash
# semgrep_summary.sh - Summarize Semgrep scan results (JSON or SARIF),
# storing outputs under code-scans/<repo_name>/summaries if specified.

###############################################################################
# Usage & Argument Parsing
###############################################################################

usage() {
    cat <<EOF
Usage: $0 [options]
  -f <semgrep_file>  Path to the Semgrep output (.json or .sarif)
  -r <repo_name>     Repository name (folder in code-scans/<repo_name>/)
  -o <base_dir>      Base output directory (default: ./output/code-scans/<repo_name>)

If you do not provide -f, the script attempts to auto-discover the newest *semgrep.json or *semgrep.sarif in the current directory or the scans/ subfolder (depending on -r usage).

The script produces two main summary files:
  - A short overview of total findings, severity distribution, and top rules
  - A detailed CSV enumerating all findings

Examples:
  # Summarize a known semgrep JSON
  ./semgrep_summary.sh -f myrepo.semgrep.json -r myrepo

  # Summarize a semgrep SARIF with a custom base dir
  ./semgrep_summary.sh -f myrepo.semgrep.sarif -r myrepo -o /custom/output

  # Auto-find semgrep.* under code-scans/fintive-core/scans
  ./semgrep_summary.sh -r fintive-core
EOF
    exit 1
}

SEM_FILE=""
REPO=""
OUTPUT_BASE=""

while getopts "f:r:o:" opt; do
    case $opt in
        f) SEM_FILE="$OPTARG" ;;
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
    local_output="${OUTPUT_BASE:-./output}/code-scans/$REPO"
    SCANS_DIR="$local_output/scans"
    SUMMARIES_DIR="$local_output/summaries"
    LOGS_DIR="$local_output/logs"
else
    local_output="${OUTPUT_BASE:-./output}"
    SCANS_DIR="$(pwd)"
    SUMMARIES_DIR="$local_output"
    LOGS_DIR="$local_output"
fi

mkdir -p "$SUMMARIES_DIR" "$LOGS_DIR"

MANIFEST="$LOGS_DIR/semgrep_summary_manifest_${timestamp}.log"

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$MANIFEST"
}

###############################################################################
# Auto-Find (if -f not given)
###############################################################################
# Looks in SCANS_DIR for something named "*semgrep.json" or "*semgrep.sarif"

find_latest_semgrep_file() {
    local exts=("*.semgrep.json" "*.semgrep.sarif" "*semgrep.json" "*semgrep.sarif")
    # We'll just do a simple `ls -t` approach
    local best=""
    for pattern in "${exts[@]}"; do
        local candidate
        candidate=$(ls -t "$SCANS_DIR"/$pattern 2>/dev/null | head -n1)
        if [ -n "$candidate" ]; then
            if [ -z "$best" ]; then
                best="$candidate"
            else
                # compare mod times, keep the newest
                if [ "$candidate" -nt "$best" ]; then
                    best="$candidate"
                fi
            fi
        fi
    done
    echo "$best"
}

if [ -z "$SEM_FILE" ]; then
    # Attempt to auto-discover
    SEM_FILE=$(find_latest_semgrep_file)
fi

if [ -z "$SEM_FILE" ] || [ ! -f "$SEM_FILE" ]; then
    log "Error: No valid Semgrep output file found in $SCANS_DIR."
    usage
fi

log "=== Semgrep Summary Started ==="
log "Using Semgrep file: $SEM_FILE"
log "Summaries => $SUMMARIES_DIR"
log "Logs => $LOGS_DIR"

###############################################################################
# Distinguish JSON vs SARIF
###############################################################################

EXT="${SEM_FILE##*.}"
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
# 1) Summaries for JSON
###############################################################################

if [ $isJSON -eq 1 ]; then
    SEMGREP_JSON="$SEM_FILE"

    # We produce two major summary files:
    #   (A) A short overview of total findings, top rules, severity distribution
    #   (B) A CSV enumerating each finding

    # (A) short overview
    SEMGREP_OVERVIEW="$SUMMARIES_DIR/semgrep_overview_${timestamp}.txt"

    # total findings
    total_findings=$(jq '.results | length' "$SEMGREP_JSON" 2>/dev/null)
    [ -z "$total_findings" ] && total_findings=0

    # severity distribution
    # semgrep JSON has a severity in `.extra.severity` or `.metadata.severity`
    # We can do something like:
    #  .results[] | .extra.severity (or .metadata.severity if extra is missing)
    # but your example shows `severity` in `.severity`

    # For resilience, we’ll prefer `.extra.severity` if present, fallback to `.severity`.
    # Then group by that. We'll produce lines like: "WARNING => 7"
    severity_dist=$(jq -r '
      .results
      | group_by((.extra.severity // .severity // "UNKNOWN"))
      | map({severity: .[0].extra.severity // .[0].severity // "UNKNOWN", count: length})
    ' "$SEMGREP_JSON" 2>/dev/null)

    # top rule_id
    # grouping by .check_id
    top_rules=$(jq -r '
      .results
      | group_by(.check_id)
      | map({rule: .[0].check_id, count: length})
      | sort_by(.count)
      | reverse
      ' "$SEMGREP_JSON" 2>/dev/null)

    {
      echo "=== Semgrep JSON Overview ==="
      echo "File: $SEMGREP_JSON"
      echo "Total Findings: $total_findings"
      echo ""
      echo "=== Severity Distribution ==="
      if [ -n "$severity_dist" ]; then
          echo "$severity_dist" | jq -r '.[] | "Severity: \(.severity), Count: \(.count)"'
      else
          echo "No severities found."
      fi
      echo ""
      echo "=== Top Rules (by check_id) ==="
      if [ -n "$top_rules" ]; then
          # show the top ~10
          echo "$top_rules" | jq -r '
            sort_by(.count) | reverse
            | .[]
            | "Rule: \(.rule), Count: \(.count)"
          ' | head -n10
      else
          echo "No rules found."
      fi
    } > "$SEMGREP_OVERVIEW"

    log "Created short overview -> $SEMGREP_OVERVIEW"

    # (B) Detailed CSV
    SEMGREP_CSV="$SUMMARIES_DIR/semgrep_detailed_${timestamp}.csv"
    echo "check_id,file_path,start_line,end_line,severity,message" > "$SEMGREP_CSV"

    # Some fields:
    # - check_id => .check_id
    # - file => .path
    # - line range => .start.line, .end.line
    # - severity => .extra.severity or .severity
    # - message => .extra.message or .extra.metadata.short_description
    #   etc. In your sample, we see `.extra.message`. If missing, fallback to `.extra.metadata`.
    # We'll also remove newlines from the message using gsub.

    jq -r '
      .results[]
      | [
          (.check_id // "N/A"),
          (.path // "N/A"),
          ( .start.line | tostring ),
          ( .end.line | tostring ),
          ( .extra.severity // .severity // "UNKNOWN" ),
          ( .extra.message // "No message" | gsub("[,\n]"; " ") )
        ]
      | @csv
    ' "$SEMGREP_JSON" >> "$SEMGREP_CSV" 2>/dev/null || {
        log "Warning: Could not parse JSON for detailed CSV as expected."
    }

    log "Created detailed CSV -> $SEMGREP_CSV"

###############################################################################
# 2) Summaries for SARIF
###############################################################################
elif [ $isSARIF -eq 1 ]; then
    SEMGREP_SARIF="$SEM_FILE"

    # We'll produce the same style of two major outputs: a short overview + a CSV.

    # (A) short overview
    SEMGREP_OVERVIEW="$SUMMARIES_DIR/semgrep_overview_${timestamp}.txt"

    # total findings => .runs[].results[] across all runs
    total_findings=$(jq '[.runs[].results[]] | length' "$SEMGREP_SARIF" 2>/dev/null)
    [ -z "$total_findings" ] && total_findings=0

    # severity distribution => .level
    # .runs[].results[].level => "error" | "warning" | "note"
    severity_dist=$(jq -r '
      [ .runs[].results[]? | {severity: .level} ]
      | group_by(.severity)
      | map({severity: .[0].severity, count: length})
    ' "$SEMGREP_SARIF" 2>/dev/null)

    # top rules => .ruleId
    top_rules=$(jq -r '
      [ .runs[].results[]? | {rule_id: .ruleId} ]
      | group_by(.rule_id)
      | map({rule: .[0].rule_id, count: length})
      | sort_by(.count) | reverse
    ' "$SEMGREP_SARIF" 2>/dev/null)

    {
      echo "=== Semgrep SARIF Overview ==="
      echo "File: $SEMGREP_SARIF"
      echo "Total Findings: $total_findings"
      echo ""
      echo "=== Severity Distribution ==="
      if [ -n "$severity_dist" ]; then
          echo "$severity_dist" | jq -r '.[] | "Severity: \(.severity), Count: \(.count)"'
      else
          echo "No severities found."
      fi
      echo ""
      echo "=== Top Rules (by ruleId) ==="
      if [ -n "$top_rules" ]; then
          echo "$top_rules" | jq -r '
            .[] | "Rule: \(.rule), Count: \(.count)"
          ' | head -n10
      else
          echo "No rules found."
      fi
    } > "$SEMGREP_OVERVIEW"

    log "Created short overview -> $SEMGREP_OVERVIEW"

    # (B) Detailed CSV
    SEMGREP_CSV="$SUMMARIES_DIR/semgrep_detailed_${timestamp}.csv"
    echo "rule_id,file_path,start_line,end_line,severity,message" > "$SEMGREP_CSV"

    # For each .runs[].results[]
    #   rule_id => .ruleId
    #   file => .locations[0].physicalLocation.artifactLocation.uri
    #   line range => .locations[0].physicalLocation.region.{startLine,endLine}
    #   severity => .level
    #   message => .message.text
    jq -r '
      .runs[]
      | .results[]
      | [
          (.ruleId // "N/A"),
          (.locations[0]?.physicalLocation?.artifactLocation?.uri // "N/A"),
          ((.locations[0]?.physicalLocation?.region?.startLine|tostring) // "N/A"),
          ((.locations[0]?.physicalLocation?.region?.endLine|tostring) // "N/A"),
          (.level // "N/A"),
          ( .message.text // "No message" | gsub("[,\n]"; " ") )
        ]
      | @csv
    ' "$SEMGREP_SARIF" >> "$SEMGREP_CSV" 2>/dev/null || {
        log "Warning: Could not parse SARIF for detailed CSV as expected."
    }

    log "Created detailed CSV -> $SEMGREP_CSV"
fi

log "=== Semgrep Summary Complete ==="
log "Manifest: $MANIFEST"
