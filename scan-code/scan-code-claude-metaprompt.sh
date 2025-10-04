#!/usr/bin/env bash
# scan-code-claude-metaprompt.sh - Automated "Claude Code" scanning prompts script
#
# Uses a SINGLE all-in-one meta-prompt that addresses multiple security domains
# in one pass. Avoids line splitting by assigning the prompt to a single array element.

###############################################################################
# Usage & Argument Parsing
###############################################################################

usage() {
    cat <<EOF
Usage: $0 [-r <repo_folder>] [-o <output_directory>]

  -r repo_folder      Path to local code repository or folder to reference.
  -o output_dir       Base output directory (default: ./output/claude-scans/<repo_name>)

Example:
  $0 -r /path/to/your/codebase -o /custom/output
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

# If an .env file exists, load it
if [ -f ".env" ]; then
    echo "Loading settings from .env"
    # shellcheck disable=SC1091
    source ".env"
fi

# If REPO wasn't provided, show usage
if [ -z "$REPO" ]; then
    echo "Error: No repository path provided."
    usage
fi

# Normalize the repo path
REPO="${REPO%/}"
REPO_BASENAME="$(basename "$REPO")"

# Determine the base output location
OUTPUT_ROOT="${OUTPUT_BASE:-$(pwd)/output/claude-scans/$REPO_BASENAME}"

SCANS_DIR="$OUTPUT_ROOT/scans"
LOGS_DIR="$OUTPUT_ROOT/logs"
SUMMARIES_DIR="$OUTPUT_ROOT/summaries"
mkdir -p "$SCANS_DIR" "$LOGS_DIR" "$SUMMARIES_DIR"

TIMESTAMP=$(date +%Y%m%d%H%M%S)
MANIFEST="$LOGS_DIR/claude_manifest_${TIMESTAMP}.log"

###############################################################################
# Logging Function
###############################################################################

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$MANIFEST"
}

###############################################################################
# Single Meta-Prompt Definition
###############################################################################

# Store the entire meta-prompt in a single variable
read -r -d '' META_PROMPT <<'EOF'
Perform a comprehensive security review of the given codebase, covering:
1. Executive & Technical Summaries
2. Architecture & Dependencies
3. Authentication & Authorization
4. User Input & Validation
5. Error Handling & Logging
6. Encryption & Secrets Management
7. Configuration & Deployment
8. Testing & Coverage
9. Risk Prioritization & Recommendations

Requirements:
- Cite any known CVEs or CWEs if possible.
- Provide specific code references if discovered.
- End with a roadmap (short-term, medium-term, long-term) for remediation.
EOF

# Put the single prompt into an array with exactly ONE element
PROMPTS_ARRAY=("$META_PROMPT")

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
