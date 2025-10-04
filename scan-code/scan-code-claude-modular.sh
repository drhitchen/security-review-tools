#!/usr/bin/env bash
# scan-code-claude-targeted.sh - Automated "Claude Code" scanning prompts script
#
# This version uses THREE broader prompts. We ensure each prompt is stored
# as a single variable, then place them in an array. We avoid line splitting
# by not using 'IFS=$'\n' read ... for the main prompt assignment.

###############################################################################
# Usage & Argument Parsing
###############################################################################

usage() {
    cat <<EOF
Usage: $0 [-r <repo_folder>] [-o <output_directory>]

  -r repo_folder      Path to local code repository or folder to reference.
  -o output_dir       Base output directory (default: ./output/claude-scans/<repo_name>)
EOF
    exit 1
}

# Defaults
OUTPUT_BASE=""
while getopts "r:o:" opt; do
    case $opt in
        r) REPO="$OPTARG" ;;
        o) OUTPUT_BASE="$OPTARG" ;;
        *) usage ;;
    esac
done

###############################################################################
# Environment Setup
###############################################################################

if [ -f ".env" ]; then
    echo "Loading settings from .env"
    # shellcheck disable=SC1091
    source ".env"
fi

if [ -z "$REPO" ]; then
    echo "Error: No repository path provided."
    usage
fi

REPO="${REPO%/}"
REPO_BASENAME="$(basename "$REPO")"

OUTPUT_ROOT="${OUTPUT_BASE:-$(pwd)/output/claude-scans/$REPO_BASENAME}"
SCANS_DIR="$OUTPUT_ROOT/scans"
LOGS_DIR="$OUTPUT_ROOT/logs"
SUMMARIES_DIR="$OUTPUT_ROOT/summaries"
mkdir -p "$SCANS_DIR" "$LOGS_DIR" "$SUMMARIES_DIR"

TIMESTAMP=$(date +%Y%m%d%H%M%S)
MANIFEST="$LOGS_DIR/claude_manifest_${TIMESTAMP}.log"

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$MANIFEST"
}

###############################################################################
# Define Each Prompt as a Single Variable
###############################################################################

read -r -d '' PROMPT_A <<'EOF'
### Prompt A: Architecture & Dependencies
Perform an architectural review and dependency check for any known vulnerabilities or outdated packages. Provide upgrade or replacement recommendations.
EOF

read -r -d '' PROMPT_B <<'EOF'
### Prompt B: Auth, Input Validation & Logging
Assess the codebase’s authentication flows, user input handling, and logging practices. Identify missing validation, potential injection points, or logging of sensitive data.
EOF

read -r -d '' PROMPT_C <<'EOF'
### Prompt C: Encryption, Secrets & Configuration Security
Analyze how data is encrypted in transit and at rest, and how secrets or credentials are managed. Check for hardcoded secrets, insecure configs, or missing TLS enforcement.
EOF

# Now place them in an array as separate elements
PROMPTS_ARRAY=(
  "$PROMPT_A"
  "$PROMPT_B"
  "$PROMPT_C"
)

###############################################################################
# Run Claude with Retries
###############################################################################

run_claude_prompt() {
    local index="$1"
    local prompt_text="$2"
    local output_file="$3"

    local final_prompt="${prompt_text}\n\nYou may reference local code in: ${REPO} if relevant."
    local tmp_output
    tmp_output="$(mktemp -t claude_output_XXXXXX)"

    local attempts=(30 60 90)
    local success=0

    for attempt_i in "${!attempts[@]}"; do
        local attempt_num=$(( attempt_i + 1 ))
        local backoff="${attempts[$attempt_i]}"

        log "Running Claude Prompt #$index (Attempt $attempt_num/3)..."

        > "$tmp_output"
        {
          echo "### Claude Security Assessment Prompt"
          echo
          echo "${prompt_text}"
          echo
          echo "---"
          echo
        } >> "$tmp_output"

        claude -p "$final_prompt" --cwd "$REPO" >> "$tmp_output" 2>&1

        if grep -qi "API Error: read ECONNRESET" "$tmp_output"; then
            log "Detected 'read ECONNRESET' error. Will retry after $backoff seconds..."
            sleep "$backoff"
            continue
        fi

        success=1
        break
    done

    if [ "$success" -eq 1 ]; then
        mv "$tmp_output" "$output_file"
        log "Prompt #$index succeeded; output -> $output_file"
    else
        {
          echo
          echo "[Error: All attempts failed due to repeated API errors.]"
        } >> "$tmp_output"
        mv "$tmp_output" "$output_file"
        log "Prompt #$index failed after 3 attempts; output -> $output_file"
    fi

    sleep 5
}

###############################################################################
# Main Execution
###############################################################################

log "=== Claude Code Security Assessment Started ==="
log "Repository       : $REPO"
log "Output Directory : $OUTPUT_ROOT"
log "Total Prompts    : ${#PROMPTS_ARRAY[@]}"

index=1
for prompt in "${PROMPTS_ARRAY[@]}"; do
    outfile="$SCANS_DIR/claude_prompt_${TIMESTAMP}_${index}.md"
    run_claude_prompt "$index" "$prompt" "$outfile"
    ((index++))
done

log "=== Claude Code Security Assessment Complete ==="
log "Raw prompt outputs are under: $SCANS_DIR"
log "Logs stored under: $LOGS_DIR"
log "Main manifest file: $MANIFEST"
