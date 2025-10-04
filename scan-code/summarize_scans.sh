#!/bin/bash

# Default values
OUTPUT_BASE_DIR="./output/code-scans"

# Parse arguments
while getopts "r:o:" opt; do
  case ${opt} in
    r ) REPO_FOLDER=$OPTARG ;;
    o ) OUTPUT_DIR=$OPTARG ;;
    * ) echo "Usage: $0 -r repo_folder [-o output_dir]"; exit 1 ;;
  esac
done

# Validate repository folder
if [[ -z "$REPO_FOLDER" ]]; then
  echo "Error: Repository folder is required (-r)."
  exit 1
fi

# Set output directory if not provided
if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="${OUTPUT_BASE_DIR}"
fi

# Find and execute all *_summary.sh scripts in the current script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for script in "$SCRIPT_DIR"/*_summary.sh; do
  if [[ -x "$script" ]]; then
    echo "Running $(basename "$script")..."
    "$script" -r "$REPO_FOLDER" -o "$OUTPUT_DIR"
  else
    echo "Skipping $(basename "$script") (not executable)."
  fi
done

echo "All summary scans completed. Logs are in $OUTPUT_DIR/$REPO_FOLDER."
