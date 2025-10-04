#!/bin/bash
# scan-code.sh - Source code security scanning script

###############################################################################
# Usage & Argument Parsing
###############################################################################

usage() {
    cat <<EOF
Usage: $0 [-r <repo_folder>] [-o <output_directory>] [-t <tool>] [-m <model>]
  -r repo_folder      Path to local code repository to scan.
  -o output_dir       Base output directory (default: ./output/code-scans/<repo_name>)
  -t tool             Which scanning tool(s) to run (default: all).
                     Options (comma-separated or single):
                       - scc
                       - detect-secrets
                       - trufflehog
                       - checkov
                       - kics
                       - semgrep
                       - trivy
                       - snyk
                       - bearer
                       - terrascan
                       - all

Note: 'all' does NOT include Terrascan. Use '-t terrascan' or '-t all,terrascan'
      if you want to run Terrascan manually.

  -m model            Which model to use (default: chatgpt-4o-latest).
EOF
    exit 1
}

# Default values
TOOL_SELECTION="all"
FABRIC_MODEL="chatgpt-4o-latest" # chatgpt-4o-latest, claude-3-7-sonnet-latest
while getopts "r:o:t:m:" opt; do
    case $opt in
        r) REPO="$OPTARG" ;;
        o) OUTPUT_BASE="$OPTARG" ;;
        t) TOOL_SELECTION="$OPTARG" ;;
        m) FABRIC_MODEL="$OPTARG" ;;
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

# If REPO wasn't provided, exit
if [ -z "$REPO" ]; then
    echo "Error: No repository path provided."
    usage
fi

# Strip trailing slash from REPO for consistent handling
REPO="${REPO%/}"

# Determine a default output location if not provided
REPO_BASENAME="$(basename "$REPO")"
OUTPUT_ROOT="${OUTPUT_BASE:-$(pwd)/output/code-scans/$REPO_BASENAME}"

# We'll store raw scans in "scans/", summaries in "summaries/", logs in "logs/"
SCANS_DIR="$OUTPUT_ROOT/scans"
SUMMARIES_DIR="$OUTPUT_ROOT/summaries"
LOGS_DIR="$OUTPUT_ROOT/logs"

# Create all subdirectories
mkdir -p "$SCANS_DIR" "$SUMMARIES_DIR" "$LOGS_DIR"

TIMESTAMP=$(date +%Y%m%d%H%M%S)
MANIFEST="$LOGS_DIR/scan_manifest_${TIMESTAMP}.log"

# Dynamically resolve the KICS queries path for Linux installation
get_kics_queries_path() {
    local queries_path=""

    # Check common Linux installation paths for KICS queries
    local possible_paths=(
        "/usr/local/share/kics/assets/queries"
        "/opt/kics/assets/queries"
        "/usr/share/kics/assets/queries"
        "$HOME/go/src/github.com/Checkmarx/kics/assets/queries"
        "$HOME/.local/share/kics/assets/queries"
    )

    for path in "${possible_paths[@]}"; do
        if [[ -d "$path" ]]; then
            queries_path="$path"
            break
        fi
    done

    # If no queries found, try to find where kics binary is and look for queries nearby
    if [[ -z "$queries_path" || ! -d "$queries_path" ]]; then
        local kics_bin="$(command -v kics 2>/dev/null)"
        if [[ -n "$kics_bin" ]]; then
            # Try to find queries relative to the kics binary location
            local kics_dir="$(dirname "$(dirname "$kics_bin")")"
            if [[ -d "$kics_dir/share/kics/assets/queries" ]]; then
                queries_path="$kics_dir/share/kics/assets/queries"
            fi
        fi
    fi

    # Final check for queries path existence
    if [[ -d "$queries_path" ]]; then
        echo "$queries_path"
    else
        echo "Error: Unable to locate KICS queries directory." >&2
        echo "Searched paths: ${possible_paths[*]}" >&2
        return 1
    fi
}

###############################################################################
# Logging Function
###############################################################################

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$MANIFEST"
}

###############################################################################
# Utility Function to Strip ANSI Color Codes
###############################################################################
strip_ansi_codes() {
    local infile="$1"
    local outfile="$2"
    if [ -f "$infile" ]; then
        sed -r "s/\x1B\[[0-9;]*[mGK]//g" "$infile" > "$outfile"
    fi
}

###############################################################################
# Scanner Functions
###############################################################################
# In each function, we write raw outputs into "$SCANS_DIR".

run_scc() {
    # Verify SCC is installed - check both system PATH and specific locations
    if ! command -v scc &> /dev/null; then
        log "Error: SCC is not installed. Please install SCC first."
        log "Installation: Run ./install-scc.sh from your modular installation framework"
        return 1
    fi

    local outfile="$SCANS_DIR/${REPO_BASENAME}.scc.txt"
    log "Running: scc (Sloc Cloc and Code) on $REPO"

    pushd "$REPO" >/dev/null 2>&1
    local cmd="scc"
    log "Debug: Executing command -> $cmd"
    eval "$cmd" | tee "$outfile"
    popd >/dev/null 2>&1
}

run_detect_secrets() {
    # Verify detect-secrets is installed - should be available via wrapper in /usr/local/bin
    if ! command -v detect-secrets &> /dev/null; then
        log "Error: detect-secrets is not installed. Please install detect-secrets first."
        log "Installation: Run ./install-detect-secrets.sh from your modular installation framework"
        return 1
    fi

    local outfile="$SCANS_DIR/${REPO_BASENAME}.detect-secrets.json"
    log "Running: detect-secrets on $REPO"

    local cmd="detect-secrets scan \"$REPO\""
    log "Debug: Executing command -> $cmd"
    eval "$cmd" | tee "$outfile"
}

run_trufflehog() {
    # Verify trufflehog is installed - should be available in /usr/local/bin
    if ! command -v trufflehog &> /dev/null; then
        log "Error: trufflehog is not installed. Please install trufflehog first."
        log "Installation: Run ./install-trufflehog.sh from your modular installation framework"
        return 1
    fi

    local outfile_txt="$SCANS_DIR/${REPO_BASENAME}.trufflehog_secrets.txt"
    local outfile_json="$SCANS_DIR/${REPO_BASENAME}.trufflehog_secrets.json"
    log "Running: TruffleHog on $REPO"

    local cmd1="trufflehog filesystem \"$REPO\" --only-verified"
    log "Debug: Executing command -> $cmd1"
    eval "$cmd1" | tee "$outfile_txt"

    local cmd2="trufflehog filesystem \"$REPO\" --only-verified --json"
    log "Debug: Executing command -> $cmd2"
    eval "$cmd2" | tee "$outfile_json"
}

run_checkov() {
    # Verify checkov is installed - should be available via wrapper in /usr/local/bin
    if ! command -v checkov &> /dev/null; then
        log "Error: checkov is not installed. Please install checkov first."
        log "Installation: Run ./install-checkov.sh from your modular installation framework"
        return 1
    fi

    local outfile_txt="$SCANS_DIR/${REPO_BASENAME}.checkov.txt"
    local outfile_json="$SCANS_DIR/${REPO_BASENAME}.checkov.json"

    log "Running: Checkov on $REPO"
    local cmd="checkov --directory \"$REPO\" --skip-path docs \
        -o cli -o json --output-file-path \"$outfile_txt\",\"$outfile_json\" --quiet"
    log "Debug: Executing command -> $cmd"
    eval "$cmd"
}

run_kics() {
    # Verify KICS is installed - should be available in /usr/local/bin  
    if ! command -v kics &> /dev/null; then
        log "Error: KICS is not installed. Please install KICS first."
        log "Installation: Run ./install-kics.sh from your modular installation framework"
        return 1
    fi

    local queries_path
    queries_path=$(get_kics_queries_path) || {
        log "Error: Could not determine KICS queries path."
        return 1
    }

    local outbase="$SCANS_DIR/${REPO_BASENAME}.kics"
    log "Running: KICS on $REPO"

    local cmd="kics scan -p \"${PWD}/$REPO\" -o \"$SCANS_DIR\" --queries-path \"$queries_path\" --no-progress --output-name \"${REPO_BASENAME}.kics\" \\
        --preview-lines 30 --report-formats csv,html,json,sarif"
    log "Debug: Executing command -> $cmd"
    eval "$cmd"

    chmod -x "${outbase}".*
}

run_semgrep() {
    # Verify semgrep is installed - should be available via wrapper in /usr/local/bin
    if ! command -v semgrep &> /dev/null; then
        log "Error: semgrep is not installed. Please install semgrep first."
        log "Installation: Run ./install-semgrep.sh from your modular installation framework"
        return 1
    fi

    local outbase="$SCANS_DIR/${REPO_BASENAME}.semgrep"
    log "Running: Semgrep on $REPO"

    local cmd="semgrep --config auto \"$REPO\" \
        --quiet --dataflow-traces --no-force-color \
        --text --output=\"${outbase}.txt\" \
        --json-output=\"${outbase}.json\" \
        --sarif-output=\"${outbase}.sarif\""
    log "Debug: Executing command -> $cmd"
    eval "$cmd"
}

run_trivy() {
    # Verify Trivy is installed - should be available in /usr/local/bin or via APT
    if ! command -v trivy &> /dev/null; then
        log "Error: Trivy is not installed. Please install Trivy first."
        log "Installation: Run ./install-trivy.sh from your modular installation framework"
        return 1
    fi

    local outfile_txt="$SCANS_DIR/${REPO_BASENAME}.trivy.txt"
    local outfile_json="$SCANS_DIR/${REPO_BASENAME}.trivy.json"
    log "Running: Trivy (file system scan) on $REPO"

    # Table output
    local cmd1="trivy fs \"${PWD}/$REPO\" --format table"
    log "Debug: Executing command -> $cmd1"
    eval "$cmd1" | tee "$outfile_txt"

    # JSON output
    local cmd2="trivy fs \"${PWD}/$REPO\" --format json"
    log "Debug: Executing command -> $cmd2"
    eval "$cmd2" | tee "$outfile_json"
}

run_snyk() {
    # Verify snyk is installed - should be available in /usr/local/bin
    if ! command -v snyk &> /dev/null; then
        log "Error: snyk is not installed. Please install snyk first."
        log "Installation: Run ./install-snyk.sh from your modular installation framework"
        return 1
    fi

    local outbase="$SCANS_DIR/${REPO_BASENAME}.snyk"
    log "Running: Snyk Code on $REPO"

    # JSON output
    local cmd1="snyk code test \"$REPO\" --json-file-output=\"${outbase}.json\""
    log "Debug: Executing command -> $cmd1"
    eval "$cmd1"

    # SARIF output
    local cmd2="snyk code test \"$REPO\" --sarif-file-output=\"${outbase}.sarif\""
    log "Debug: Executing command -> $cmd2"
    eval "$cmd2"
}

run_bearer() {
    # Verify bearer is installed - should be available via APT installation
    if ! command -v bearer &> /dev/null; then
        log "Error: bearer is not installed. Please install bearer first."
        log "Installation: Run ./install-bearer.sh from your modular installation framework"
        return 1
    fi

    local outbase="$SCANS_DIR/${REPO_BASENAME}.bearer"
    log "Running: Bearer on $REPO"

    # Security (HTML)
    local cmd1="bearer scan \"$REPO\" --report security --format html --output \"${outbase}_security.html\""
    log "Debug: Executing command -> $cmd1"
    eval "$cmd1"

    # Security (JSON)
    local cmd2="bearer scan \"$REPO\" --report security --format json --output \"${outbase}_security.json\""
    log "Debug: Executing command -> $cmd2"
    eval "$cmd2"

    # Privacy (HTML)
    local cmd3="bearer scan \"$REPO\" --report privacy --format html --output \"${outbase}_privacy.html\""
    log "Debug: Executing command -> $cmd3"
    eval "$cmd3"

    # Privacy (JSON)
    local cmd4="bearer scan \"$REPO\" --report privacy --format json --output \"${outbase}_privacy.json\""
    log "Debug: Executing command -> $cmd4"
    eval "$cmd4"
}

run_terrascan() {
    # Verify terrascan is installed - should be available in /usr/local/bin
    if ! command -v terrascan &> /dev/null; then
        log "Error: terrascan is not installed. Please install terrascan first."
        log "Installation: Run ./install-terrascan.sh from your modular installation framework"
        return 1
    fi

    local outfile_txt="$SCANS_DIR/${REPO_BASENAME}.terrascan.txt"
    local outfile_json="$SCANS_DIR/${REPO_BASENAME}.terrascan.json"
    log "Running: Terrascan on $REPO"

    pushd "$REPO" >/dev/null 2>&1

    local cmd1="terrascan scan . --output human"
    log "Debug: Executing command -> $cmd1"
    eval "$cmd1" | tee "$outfile_txt"

    local cmd2="terrascan scan . --output json"
    log "Debug: Executing command -> $cmd2"
    eval "$cmd2" | tee "$outfile_json"

    popd >/dev/null 2>&1
}

###############################################################################
# Main Execution Block
###############################################################################

log "=== Code Scan Started ==="
log "Parameters:"
log "  Repository       : $REPO"
log "  Output Directory : $OUTPUT_ROOT"
log "  Tools to run     : $TOOL_SELECTION"

IFS=',' read -ra TOOLS <<< "$TOOL_SELECTION"
ALL_TOOLS=("scc" "detect-secrets" "trufflehog" "checkov" "kics" "semgrep" "trivy" "snyk" "bearer")

# 'all' does NOT include Terrascan by default
if [[ " ${TOOLS[@]} " =~ " all " ]]; then
    TOOLS=("${ALL_TOOLS[@]}")
fi

# De-duplicate
UNIQUE_TOOLS=()
for t in "${TOOLS[@]}"; do
    [[ " ${UNIQUE_TOOLS[*]} " =~ " $t " ]] || UNIQUE_TOOLS+=("$t")
done
log "Resolved tool list: ${UNIQUE_TOOLS[*]}"

# Run each requested tool
for tool in "${UNIQUE_TOOLS[@]}"; do
    case "$tool" in
        scc)             run_scc ;;
        detect-secrets)  run_detect_secrets ;;
        trufflehog)      run_trufflehog ;;
        checkov)         run_checkov ;;
        kics)            run_kics ;;
        semgrep)         run_semgrep ;;
        trivy)           run_trivy ;;
        snyk)            run_snyk ;;
        bearer)          run_bearer ;;
        terrascan)       run_terrascan ;;  # not in 'all' by default
        *)
            log "Warning: Unknown tool '$tool' - skipping."
            ;;
    esac
done

# Strip color codes from Checkov or Semgrep text outputs if they exist
if [ -f "$SCANS_DIR/${REPO_BASENAME}.checkov.txt" ]; then
    strip_ansi_codes "$SCANS_DIR/${REPO_BASENAME}.checkov.txt" \
        "$SCANS_DIR/${REPO_BASENAME}.checkov.nocolor.txt"
fi
if [ -f "$SCANS_DIR/${REPO_BASENAME}.semgrep.txt" ]; then
    strip_ansi_codes "$SCANS_DIR/${REPO_BASENAME}.semgrep.txt" \
        "$SCANS_DIR/${REPO_BASENAME}.semgrep.nocolor.txt"
fi

###############################################################################
# Summaries or Post-Processing
###############################################################################
log "Starting summary scripts..."

# Verify summarize_scans.sh is in the same directory as this script or in PATH
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -x "$SCRIPT_DIR/summarize_scans.sh" ]; then
    SUMMARIZE_SCRIPT="$SCRIPT_DIR/summarize_scans.sh"
elif command -v summarize_scans.sh &> /dev/null; then
    SUMMARIZE_SCRIPT="summarize_scans.sh"
else
    log "Error: summarize_scans.sh is not found in $SCRIPT_DIR or PATH."
    return 1
fi

log "Running: summarize_scans.sh on $REPO scan results"
"$SUMMARIZE_SCRIPT" -r "${REPO}" -o "${OUTPUT_ROOT}"

# Verify fabric_reports.sh is available
if [ -x "$SCRIPT_DIR/fabric_reports.sh" ]; then
    FABRIC_SCRIPT="$SCRIPT_DIR/fabric_reports.sh"
elif command -v fabric_reports.sh &> /dev/null; then
    FABRIC_SCRIPT="fabric_reports.sh"
else
    log "Warning: fabric_reports.sh is not found in $SCRIPT_DIR or PATH. Skipping fabric reports."
    FABRIC_SCRIPT=""
fi

if [ -n "$FABRIC_SCRIPT" ]; then
    if ! command -v fabric &> /dev/null; then
        log "Warning: fabric is not found in PATH. Skipping fabric reports."
    else
        log "Running: fabric_reports.sh on $REPO scan results"
        "$FABRIC_SCRIPT" -r "${REPO}" -o "${OUTPUT_ROOT}" -m "${FABRIC_MODEL}"
    fi
fi

###############################################################################
# Final Summary
###############################################################################

log "=== Code Scan Complete ==="
log "Raw scans stored under: $SCANS_DIR"
log "Summaries stored under: $SUMMARIES_DIR"
log "Logs stored under: $LOGS_DIR"
log "Main manifest file: $MANIFEST"
