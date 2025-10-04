#!/bin/bash

# Dynamically resolve script directory for bash/zsh
get_script_dir() {
    local script_path
    if [[ -n "$BASH_SOURCE" ]]; then
        script_path="${BASH_SOURCE[0]}"
    elif [[ -n "$ZSH_VERSION" ]]; then
        script_path="${(%):-%x}"
    else
        echo "Unsupported shell. Use bash or zsh." >&2
        return 1
    fi
    cd "$(dirname "$script_path")/.." && pwd  # Move up one level
}

# Dynamically add Security Review Tools directories to PATH
add_security_review_tools() {
    local base_dir
    base_dir="$(get_script_dir)" || return 1

    local dirs=("scan-account" "scan-code" "tools")

    for dir in "${dirs[@]}"; do
        full_path="$base_dir/$dir"
        if [[ -d "$full_path" ]]; then
            if [[ ":$PATH:" != *":$full_path:"* ]]; then
                export PATH="$full_path:$PATH"
                echo "Added $full_path to PATH"
            else
                echo "$full_path already in PATH"
            fi
        else
            echo "Directory $full_path does not exist."
        fi
    done
}

# Detect if the script was sourced or executed directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]] || [[ -n "$ZSH_EVAL_CONTEXT" && "$ZSH_EVAL_CONTEXT" == "toplevel" ]]; then
    echo "Warning: Script executed directly. PATH changes won't persist."
    echo "For persistent updates, run:"
    echo "  source \"$0\""
    add_security_review_tools
else
    add_security_review_tools
fi
