#!/usr/bin/env bash
#
# scan-code-claude.sh - Master script to invoke:
#   1) scan-code-claude-modular.sh
#   2) scan-code-claude-metaprompt.sh
# or both, based on user arguments.
#
# Place this script in the same directory as:
#   - scan-code-claude-modular.sh
#   - scan-code-claude-metaprompt.sh
#
# Usage Examples:
#   ./scan-code-claude.sh -m -r /path/to/repo -o /path/to/output
#   ./scan-code-claude.sh -M -r /path/to/repo -o /path/to/output
#   ./scan-code-claude.sh -b -r /path/to/repo -o /path/to/output
#

###############################################################################
# Usage & Argument Parsing
###############################################################################

usage() {
  echo "Usage: $0 [OPTIONS] -r <repo_folder>"
  echo ""
  echo "  -m   Run Modular script only (scan-code-claude-modular.sh)"
  echo "  -M   Run Meta script only (scan-code-claude-metaprompt.sh)"
  echo "  -b   Run Both scripts sequentially"
  echo "  -r   Path to local code repository or folder to reference"
  echo "  -o   Output directory (optional)"
  echo ""
  echo "Examples:"
  echo "  $0 -m -r /path/to/my/repo -o /custom/output"
  echo "  $0 -M -r /path/to/my/repo"
  echo "  $0 -b -r /path/to/my/repo"
  exit 1
}

# Initialize
RUN_MODULAR=0
RUN_META=0
REPO=""
OUTPUT_BASE=""

while getopts "mMbBr:o:" opt; do
  case "$opt" in
    m|M|b)
      # We allow multiple flags: -m -M => runs both, for instance
      case "$opt" in
        m) RUN_MODULAR=1 ;;
        M) RUN_META=1    ;;
        b) RUN_MODULAR=1; RUN_META=1 ;;
      esac
      ;;
    r)
      REPO="$OPTARG"
      ;;
    o)
      OUTPUT_BASE="$OPTARG"
      ;;
    *)
      usage
      ;;
  esac
done

# Validate we have at least one script to run
if [[ $RUN_MODULAR -eq 0 && $RUN_META -eq 0 ]]; then
  echo "Error: No scripts selected. Use -m, -M, or -b."
  usage
fi

# Validate REPO param
if [[ -z "$REPO" ]]; then
  echo "Error: -r <repo_folder> is required."
  usage
fi

###############################################################################
# Environment Setup
###############################################################################

# If there's an .env file in the current directory, load it
if [ -f ".env" ]; then
  echo "Loading settings from .env"
  # shellcheck disable=SC1091
  source ".env"
fi

# Normalize path (strip trailing slash)
REPO="${REPO%/}"

###############################################################################
# Run the Requested Scripts
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $RUN_MODULAR -eq 1 ]]; then
  echo "Running Modular script (scan-code-claude-modular.sh)..."
  "${SCRIPT_DIR}/scan-code-claude-modular.sh" -r "$REPO" ${OUTPUT_BASE:+-o "$OUTPUT_BASE"}
fi

if [[ $RUN_META -eq 1 ]]; then
  echo "Running Meta script (scan-code-claude-metaprompt.sh)..."
  "${SCRIPT_DIR}/scan-code-claude-metaprompt.sh" -r "$REPO" ${OUTPUT_BASE:+-o "$OUTPUT_BASE"}
fi

echo "Done."
