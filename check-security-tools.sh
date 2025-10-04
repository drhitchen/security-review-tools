#!/bin/bash

set -euo pipefail

# ANSI color codes
GREEN="\033[0;32m"
RED="\033[0;31m"
DIM="\033[2m"
RESET="\033[0m"

# Emojis
CHECK="${GREEN}✅${RESET}"
CROSS="${RED}❌${RESET}"

# All tools to check - updated for Linux modular installation
tools_system=(
  bearer
  checkov
  detect-secrets
  jq
  kics
  scc
  semgrep
  snyk
  terrascan
  trivy
  trufflehog
)

tools_venv=(
  gitingest
  prowler
  scout
)

# Determine maximum tool name length for alignment
maxlen() {
  local max=0
  for t in "$@"; do
    [ ${#t} -gt $max ] && max=${#t}
  done
  echo $max
}
pad_to() {
  local s=$1; local len=$2
  printf "%-${len}s" "$s"
}

max_tool_len=$(maxlen "${tools_system[@]}" "${tools_venv[@]}")

# Check tool availability in PATH
check_command_tool() {
  local name=$1
  local label=$2
  local padded
  padded=$(pad_to "$name" "$max_tool_len")

  if command -v "$name" >/dev/null 2>&1; then
    echo -e "${CHECK} ${padded}  (${label})"
  else
    echo -e "${CROSS} ${padded}  (${label}) ${DIM}NOT found${RESET}"
  fi
}

# Begin output
echo -e "\n🔍 ${DIM}Checking installed tools...${RESET}"

echo -e "\n🔧 ${DIM}System-installed tools (via modular framework):${RESET}"
for tool in "${tools_system[@]}"; do
  check_command_tool "$tool" "system"
done

echo -e "\n🐍 ${DIM}Python virtualenv tools:${RESET}"
for tool in "${tools_venv[@]}"; do
  check_command_tool "$tool" "python/venv"
done

echo -e "\n${CHECK} ${DIM}Tool check complete.${RESET}"
