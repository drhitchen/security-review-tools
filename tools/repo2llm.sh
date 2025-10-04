#!/usr/bin/env bash
#
# c2p.sh - Generate a structured view of a project directory, honoring a basic .gitignore.
# Compatible with macOS default Bash 3.2 (no associative arrays).
#

###############################################################################
# DEFAULT CONFIG
###############################################################################
default_patterns=("*.sh" "*.py" "*.js" "*.ts" "*.php" "*.html" "*.css" "*.md" "*.txt")
exclude=(".DS_Store" ".env" "log" "node_modules" "output_*.md" "tmp" "venv" "wip") # Always exclude
directory_depth=2
commit_history_depth=5
project_name="$(basename "$PWD")"

date_stamp=$(date +"%Y%m%d_%H%M%S")
output_file="output_${date_stamp}.md"

###############################################################################
# USAGE
###############################################################################
print_usage() {
  echo "Usage: $0 [options] [patterns...]"
  echo "Options:"
  echo "  -d <depth>   Directory depth (default: 2)"
  echo "  -x <exclude> Comma-separated excludes (e.g. 'venv,node_modules')"
  echo "  -c <commits> Number of git commits to analyze (default: ${commit_history_depth})"
  echo "  -h           Show usage/exit"
  echo
  echo "If no [patterns] are provided, uses default patterns: ${default_patterns[*]}"
}

###############################################################################
# PARSE ARGS
###############################################################################
while getopts "d:x:c:h" opt; do
  case $opt in
    d)
      directory_depth="$OPTARG"
      ;;
    x)
      IFS=',' read -r -a user_excludes <<< "$OPTARG"
      exclude=("${exclude[@]}" "${user_excludes[@]}")
      ;;
    c)
      commit_history_depth="$OPTARG"
      ;;
    h)
      print_usage
      exit 0
      ;;
    *)
      print_usage
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

###############################################################################
# BASIC .GITIGNORE PARSING
###############################################################################
gitignore_entries=()
if [ -f .gitignore ]; then
  while IFS= read -r line; do
    # Trim leading/trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    # Skip blank or comment (#)
    case "$line" in
      ""|\#*) continue ;;
    esac

    # We'll store this line in an array for special handling
    gitignore_entries+=("$line")
  done < .gitignore
fi

###############################################################################
# DETERMINE PATTERNS (if user gave none, fall back to defaults)
###############################################################################
if [ $# -eq 0 ]; then
  patterns=("${default_patterns[@]}")
else
  # The user specified patterns. We'll also remove any that match 'exclude'.
  patterns=()
  for arg in "$@"; do
    skip_pattern=false
    for ex in "${exclude[@]}"; do
      case "$arg" in
        $ex)
          skip_pattern=true
          break
          ;;
      esac
    done
    [ "$skip_pattern" = false ] && patterns+=("$arg")
  done
  # If no patterns remain after that, revert to defaults
  [ ${#patterns[@]} -eq 0 ] && patterns=("${default_patterns[@]}")
fi

###############################################################################
# BUILD THE FIND COMMAND
###############################################################################
find_cmd="find ."
# Limit depth
if [ "$directory_depth" -ge 0 ]; then
  find_cmd="$find_cmd -maxdepth $directory_depth"
fi

###############################################################################
# HELPER: CONVERT .gitignore LINES TO FIND EXCLUDES
###############################################################################
# We do a simple approach:
#  1) If line ends with '/', treat it as a directory => exclude "*/dir" and "*/dir/*"
#  2) Otherwise, treat it as a file/pattern => exclude "*/filename" and possibly -name for wildcards
#  3) This won't handle '!' negations or leading '/' nuances, but suffices for typical usage.
###############################################################################
for exline in "${gitignore_entries[@]}"; do
  # Example exline: "wip/" or ".DS_Store" or "*.log"
  # Remove a trailing slash if present => indicates directory
  # e.g. "wip/" -> "wip", note it as is_directory=true
  is_directory=false
  trimmed="$exline"

  # If the line ends with slash => directory
  if [ "${trimmed%/}" != "$trimmed" ]; then
    is_directory=true
    trimmed="${trimmed%/}"  # remove trailing slash
  fi

  # If it's a directory, exclude '*/DIR' and '*/DIR/*'
  if [ "$is_directory" = true ]; then
    # Avoid empty pattern if line was just "/"
    [ -n "$trimmed" ] && find_cmd="$find_cmd ! -path '*/$trimmed' ! -path '*/$trimmed/*'"
  else
    # If it has a wildcard, we rely on '-name' check
    # e.g. "*.log" => ! -name '*.log'
    # For direct files like ".DS_Store", we do both path and name exclude
    case "$trimmed" in
      *"*"*)
        # There's a wildcard
        find_cmd="$find_cmd ! -name \"$trimmed\""
        ;;
      *)
        # No wildcard => exclude path and name
        find_cmd="$find_cmd ! -path '*/$trimmed' ! -name '$trimmed'"
        ;;
    esac
  fi
done

# Also handle the built-in exclude array (venv, node_modules, etc.)
for ex in "${exclude[@]}"; do
  # We'll do the same approach:
  is_directory=false
  trimmed="$ex"
  if [ "${trimmed%/}" != "$trimmed" ]; then
    is_directory=true
    trimmed="${trimmed%/}"
  fi
  if [ "$is_directory" = true ] && [ -n "$trimmed" ]; then
    find_cmd="$find_cmd ! -path '*/$trimmed' ! -path '*/$trimmed/*'"
  else
    case "$trimmed" in
      *"*"*)
        find_cmd="$find_cmd ! -name \"$trimmed\""
        ;;
      *)
        find_cmd="$find_cmd ! -path '*/$trimmed' ! -name '$trimmed'"
        ;;
    esac
  fi
done

###############################################################################
# CAPTURE MATCHED FILES
###############################################################################
matched_files=()
for pattern in "${patterns[@]}"; do
  while read -r file; do
    [ -f "$file" ] && matched_files+=("$file")
  done < <(eval "$find_cmd -type f -name \"$pattern\" 2>/dev/null")
done

###############################################################################
# DE-DUPLICATE
###############################################################################
unique_files=()
for f in "${matched_files[@]}"; do
  already="no"
  for uf in "${unique_files[@]}"; do
    [ "$f" = "$uf" ] && already="yes" && break
  done
  [ "$already" = "no" ] && unique_files+=("$f")
done

###############################################################################
# STATUS OUTPUT
###############################################################################
>&2 echo "Generating structured project view for: $project_name"
>&2 echo "Directory depth: $directory_depth"
>&2 echo "Excluded files/folders (from .gitignore + builtin):"
for e in "${gitignore_entries[@]}"; do >&2 echo "  - $e"; done
for e in "${exclude[@]}"; do >&2 echo "  - $e"; done

>&2 echo "Matching patterns: ${patterns[*]}"
>&2 echo "Processing files:"
for file in "${unique_files[@]}"; do
  >&2 echo "  - $file"
done
>&2 echo "Analyzing last $commit_history_depth git commits"

[ ${#unique_files[@]} -eq 0 ] && >&2 echo "Warning: No files matched after filtering."

###############################################################################
# GENERATE OUTPUT
###############################################################################
{
  echo ":::
"
  echo "Project Path: $project_name"
  echo
  echo "Source Tree:"
  echo
  echo '```'
  # This might not fully respect .gitignore in the 'tree' output, but we hide errors
  tree -L "$directory_depth" --gitignore 2>/dev/null
  echo '```'

  for file in "${unique_files[@]}"; do
    rel_path="$(realpath --relative-to=. "$file" 2>/dev/null || echo "$file")"
    echo
    echo "### BEGIN: $rel_path ###"
    echo
    echo "\`\`\`${file##*.}"
    cat "$file"
    echo
    echo "\`\`\`"
    echo "### END: $rel_path ###"
    echo
  done

  if [ -d .git ]; then
    echo
    echo "Git Commit History (Last $commit_history_depth commits):"
    echo
    echo '```'
    GIT_PAGER=cat git log -n "$commit_history_depth" --pretty=format:"%h - %an, %ar: %s"
    echo
    echo '```'

    echo
    echo "Git Diff History (Last $commit_history_depth commits):"
    echo
    echo '```'
    GIT_PAGER=cat git log -p -n "$commit_history_depth" --stat
    echo
    echo '```'
  fi

  echo
  echo ":::"
} > "$output_file"

###############################################################################
# COPY TO CLIPBOARD
###############################################################################
if command -v pbcopy &>/dev/null; then
  pbcopy < "$output_file"
  echo "▹▹▹▹▸ Done! [✓] Copied to clipboard successfully."
else
  echo "▹▹▹▹▸ Done! [✗] Clipboard copy not available. See $output_file."
fi
