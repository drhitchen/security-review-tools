#!/bin/bash
# trivy_summary.sh - Summarize Trivy FS scan results with more actionable details.
# Handles both top-level array and {"Results": [...]} JSON formats from Trivy.

###############################################################################
# Usage & Argument Parsing
###############################################################################

usage() {
    cat <<EOF
Usage: $0 [options]
  -f <trivy_text_file>   Path to Trivy .txt (table format output)
  -j <trivy_json_file>   Path to Trivy .json
  -r <repo_name>         Repository name for code-scans/<repo_name>/
  -o <base_dir>          Base output directory (default: ./output/code-scans/<repo_name>)

Examples:
  # Summarize an existing text and JSON result for repo "fintive-core"
  ./trivy_summary.sh -f ./output/code-scans/fintive-core/scans/fintive-core.trivy.txt \\
                     -j ./output/code-scans/fintive-core/scans/fintive-core.trivy.json \\
                     -r fintive-core

  # Summarize with auto-discovery
  ./trivy_summary.sh -r fintive-core

  # Summarize with custom base path
  ./trivy_summary.sh -j myrepo.trivy.json -r myrepo -o /custom/path
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
# Environment & Output Folders
###############################################################################

TIMESTAMP=$(date +%Y%m%d%H%M%S)

if [ -n "$REPO" ]; then
    LOCAL_OUTPUT="${OUTPUT_BASE:-$(pwd)/output}/code-scans/$REPO"
    SCANS_DIR="$LOCAL_OUTPUT/scans"
    SUMMARIES_DIR="$LOCAL_OUTPUT/summaries"
    LOGS_DIR="$LOCAL_OUTPUT/logs"
else
    LOCAL_OUTPUT="${OUTPUT_BASE:-$(pwd)/output}"
    # If no repo is provided, just assume the current folder for scanning
    SCANS_DIR="$(pwd)"
    SUMMARIES_DIR="$LOCAL_OUTPUT"
    LOGS_DIR="$LOCAL_OUTPUT"
fi

mkdir -p "$SUMMARIES_DIR" "$LOGS_DIR"
MANIFEST="$LOGS_DIR/trivy_summary_manifest_${TIMESTAMP}.log"

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$MANIFEST"
}

###############################################################################
# Auto-Find Logic
###############################################################################

find_latest_trivy_file() {
    local ext="$1"  # "txt" or "json"
    local best=""
    local pattern="*trivy.$ext"
    local candidate
    # Pick the newest by modification time
    candidate=$(ls -t "$SCANS_DIR"/$pattern 2>/dev/null | head -n 1)
    if [ -n "$candidate" ] && [ -f "$candidate" ]; then
        best="$candidate"
    fi
    echo "$best"
}

# If not given, auto-discover the newest .txt and .json
if [ -z "$TXT_FILE" ]; then
    found_txt=$(find_latest_trivy_file "txt")
    [ -n "$found_txt" ] && TXT_FILE="$found_txt"
fi

if [ -z "$JSON_FILE" ]; then
    found_json=$(find_latest_trivy_file "json")
    [ -n "$found_json" ] && JSON_FILE="$found_json"
fi

###############################################################################
# Main
###############################################################################

log "=== Trivy Summary Started ==="
log "Text file     : $TXT_FILE"
log "JSON file     : $JSON_FILE"
log "Summaries in  : $SUMMARIES_DIR"
log "Logs in       : $LOGS_DIR"

###############################################################################
# 1) Minimal Text Summary from .txt
###############################################################################

if [ -n "$TXT_FILE" ] && [ -f "$TXT_FILE" ]; then
    TRIVY_TXT_SUMMARY="$SUMMARIES_DIR/trivy_txt_summary_${TIMESTAMP}.txt"
    # Grab lines around the 'Total:' summary
    grep -B2 'Total:' "$TXT_FILE" > "$TRIVY_TXT_SUMMARY" 2>/dev/null || true
    log "Trivy text summary -> $TRIVY_TXT_SUMMARY"
elif [ -n "$TXT_FILE" ]; then
    log "Warning: Provided Trivy text file '$TXT_FILE' not found."
fi

###############################################################################
# 2) JSON Summaries
###############################################################################

if [ -n "$JSON_FILE" ] && [ -f "$JSON_FILE" ]; then

    # A JQ function to unify either top-level array or { "Results": [...] }
    read -r -d '' JQ_COMMON <<'EOF'
def resultsOrArray:
  if (type == "object") and has("Results") then .Results
  elif (type == "array") then .
  else [] end;
EOF

    ###########################################################################
    # 2a) Basic JSON summary (count by VulnerabilityID)
    ###########################################################################
    TRIVY_JSON_SUMMARY="$SUMMARIES_DIR/trivy_json_summary_${TIMESTAMP}.json"
    jq "
      $JQ_COMMON
      resultsOrArray
      | [
          .[]?.Vulnerabilities[]?
          | { vuln_id: .VulnerabilityID }
        ]
      | group_by(.vuln_id)
      | map({ id: .[0].vuln_id, count: length })
    " "$JSON_FILE" > "$TRIVY_JSON_SUMMARY" 2>/dev/null || {
        log "Warning: Could not parse JSON for ID-based summary."
    }
    log "Trivy (basic) JSON summary -> $TRIVY_JSON_SUMMARY"

    ###########################################################################
    # 2b) Detailed CSV (corrected for array-based or .Results-based JSON)
    ###########################################################################
    TRIVY_JSON_DETAILED="$SUMMARIES_DIR/trivy_detailed_${TIMESTAMP}.csv"
    {
      echo "TargetFile,VulnerabilityID,Severity,Package,InstalledVersion,FixedVersion,Title,PrimaryURL"
      jq -r "
        $JQ_COMMON
        resultsOrArray
        | .[]?
        | .Target as \$target
        | .Vulnerabilities[]?
        | [
            \$target,
            (.VulnerabilityID // \"N/A\"),
            (.Severity // \"UNKNOWN\"),
            (.PkgName // \"N/A\"),
            (.InstalledVersion // \"N/A\"),
            (.FixedVersion // \"N/A\"),
            ((.Title // \"No Title\") | gsub(\"[,\n]\"; \" \")),
            (.PrimaryURL // \"N/A\")
          ]
        | @csv
      " "$JSON_FILE" 2>/dev/null || true
    } > "$TRIVY_JSON_DETAILED"
    log "Trivy (detailed) CSV -> $TRIVY_JSON_DETAILED"

    ###########################################################################
    # 2c) Severity Counts (JSON)
    ###########################################################################
    TRIVY_SEVERITY_COUNTS="$SUMMARIES_DIR/trivy_severity_counts_${TIMESTAMP}.json"
    jq "
      $JQ_COMMON
      resultsOrArray
      | [
          .[]?.Vulnerabilities[]?
          | .Severity
        ]
      | group_by(.)
      | map({ severity: .[0], count: length })
    " "$JSON_FILE" > "$TRIVY_SEVERITY_COUNTS" 2>/dev/null || {
        log "Warning: Could not parse JSON for severity counts."
    }
    log "Trivy (severity counts) -> $TRIVY_SEVERITY_COUNTS"

    ###########################################################################
    # 2d) Actionable Insights (Text) - recommended upgrades/fixes
    ###########################################################################
    TRIVY_ACTIONABLE_SUMMARY="$SUMMARIES_DIR/trivy_actionable_summary_${TIMESTAMP}.txt"
    {
      echo "==========================="
      echo " Actionable Vulnerability Insights"
      echo "==========================="
      echo
      jq -r "
        $JQ_COMMON
        resultsOrArray
        | .[]? as \$r
        | \"Target File: \" + (\$r.Target // \"N/A\") + \"\\n\"
        + (
          \$r.Vulnerabilities[]?
          | \"  - VulnerabilityID: \\(.VulnerabilityID)\\n\"
            + \"    Severity       : \\(.Severity)\\n\"
            + \"    Package        : \\(.PkgName)\\n\"
            + \"    Installed      : \\(.InstalledVersion)\\n\"
            + \"    Fixed          : \\(.FixedVersion // \"N/A\")\\n\"
            + \"    Title          : \\(.Title | gsub(\"[\\n\\r]\"; \" \"))\\n\"
            + \"    URL            : \\(.PrimaryURL // \"N/A\")\\n\"
            + \"    Recommended    : \" +
              (if (.FixedVersion // \"\") != \"\" and (.FixedVersion // \"\") != \"N/A\"
               then \"Upgrade to \" + .FixedVersion
               else \"Check references; no fixed version known.\"
               end)
            + \"\\n\"
        )
      " "$JSON_FILE"
    } > "$TRIVY_ACTIONABLE_SUMMARY"
    log "Trivy (actionable summary) -> $TRIVY_ACTIONABLE_SUMMARY"

else
    if [ -n "$JSON_FILE" ]; then
        log "Warning: Provided Trivy JSON file '$JSON_FILE' not found."
    fi
fi

###############################################################################
# Done
###############################################################################

log "=== Trivy Summary Complete ==="
log "Manifest file: $MANIFEST"
