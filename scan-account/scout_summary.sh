#!/bin/bash
# scout_summary.sh - Summarize ScoutSuite results, storing outputs in the
# same structured directories used by scan-account.sh.

###############################################################################
# Usage & Argument Parsing
###############################################################################

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  -f <scoutsuite_results.js>  Path to the ScoutSuite .scoutsuite.js file (default: auto-find latest)
  -a <aws_account>            AWS Account ID (optional; places files under account-scans/<AWS_ACCOUNT>/summaries)
  -o <base_output_dir>        Base output directory (default: ./output)
EOF
    exit 1
}

SCOUT_FILE=""
AWS_ACCOUNT=""
OUTPUT_BASE="./output"

while getopts "f:a:o:" opt; do
    case $opt in
        f) SCOUT_FILE="$OPTARG" ;;
        a) AWS_ACCOUNT="$OPTARG" ;;
        o) OUTPUT_BASE="$OPTARG" ;;
        *) usage ;;
    esac
done

###############################################################################
# Environment Setup
###############################################################################

timestamp=$(date +%Y%m%d%H%M%S)

if [ -n "$AWS_ACCOUNT" ]; then
  # Place outputs in account-scans/<AWS_ACCOUNT>/summaries
  ACCOUNT_DIR="$OUTPUT_BASE/account-scans/$AWS_ACCOUNT"
  SUMMARIES_DIR="$ACCOUNT_DIR/summaries"
  LOGS_DIR="$ACCOUNT_DIR/logs"
else
  # Fallback if no account specified
  SUMMARIES_DIR="$OUTPUT_BASE/summaries"
  LOGS_DIR="$OUTPUT_BASE/logs"
fi

mkdir -p "$SUMMARIES_DIR" "$LOGS_DIR"

MANIFEST="$LOGS_DIR/scoutsuite_manifest_${timestamp}.log"

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$MANIFEST"
}

###############################################################################
# Auto-Find File If Not Provided
###############################################################################

find_latest_scoutsuite_json() {
    local latest_file
    latest_file=$(find . -type f -name "scoutsuite_results_*.scoutsuite.js" 2>/dev/null \
        | xargs ls -t 2>/dev/null \
        | head -n 1)
    echo "$latest_file"
}

if [[ -z "$SCOUT_FILE" ]]; then
    SCOUT_FILE="$(find_latest_scoutsuite_json)"
fi

if [[ -z "$SCOUT_FILE" || ! -f "$SCOUT_FILE" ]]; then
    log "No valid ScoutSuite .scoutsuite.js file found!"
    exit 1
fi

###############################################################################
# Summarization
###############################################################################

log "=== ScoutSuite Summary ==="
log "Using ScoutSuite file: $SCOUT_FILE"

PRETTY_JSON_FILE="$SUMMARIES_DIR/scoutsuite_results.pretty_${timestamp}.js"
tail -n +2 "$SCOUT_FILE" | jq '.' | tee "$PRETTY_JSON_FILE"
log "Pretty-printed JSON -> $PRETTY_JSON_FILE"

SG_RAW_FILE="$SUMMARIES_DIR/scoutsuite_security_groups_${timestamp}.txt"
tail -n +2 "$SCOUT_FILE" | jq '.services.ec2.regions[].vpcs[].security_groups[]' | tee "$SG_RAW_FILE"
log "Security groups raw output -> $SG_RAW_FILE"

SG_SUMMARY_FILE="$SUMMARIES_DIR/scoutsuite_sg_summary_${timestamp}.txt"
tail -n +2 "$SCOUT_FILE" | jq -r '
  .services.ec2.regions[].vpcs[].security_groups[]
  | select(type == "object")
  | {name, id, ingress: (.rules.ingress.count // 0), egress: (.rules.egress.count // 0)}
' | tee "$SG_SUMMARY_FILE"
log "Security groups summary -> $SG_SUMMARY_FILE"

SG_DETAILED_FILE="$SUMMARIES_DIR/scoutsuite_sg_detailed_${timestamp}.txt"
tail -n +2 "$SCOUT_FILE" | jq -r '
  .services.ec2.regions[].vpcs[].security_groups
  | to_entries[]
  | .value
  | select(.rules | type == "object")
  | [
      (.name // "N/A"),
      (.id // "N/A"),
      (.rules.ingress.count // 0 | tostring),
      (.rules.egress.count // 0 | tostring)
    ]
' | tee "$SG_DETAILED_FILE"
log "Detailed SG report -> $SG_DETAILED_FILE"

REGIONS_FILE="$SUMMARIES_DIR/scoutsuite_regions_${timestamp}.txt"
(
  echo -e "Region Name\tStatus"
  tail -n +2 "$SCOUT_FILE" | jq -r '
    .services.ec2.regions
    | to_entries[]
    | select(.value.vpcs_count > 0 or .value.security_groups_count > 0)
    | [.key, "Enabled"]
    | @tsv
  '
) | column -t -s $'\t' | tee "$REGIONS_FILE"
log "Enabled regions summary -> $REGIONS_FILE"

SG_BASIC_TABLE_FILE="$SUMMARIES_DIR/scoutsuite_sg_basic_table_${timestamp}.txt"
(
  echo -e "Region\tName\tSG ID\tIngress Rules\tEgress Rules"
  tail -n +2 "$SCOUT_FILE" | jq -r '
    .services.ec2.regions
    | to_entries[]
    | . as $regionEntry
    | $regionEntry.value.vpcs[]
    | .security_groups
    | to_entries[]
    | .value
    | select(.rules | type == "object")
    | [
        $regionEntry.key,
        (.name // "N/A"),
        (.id // "N/A"),
        (.rules.ingress.count // 0 | tostring),
        (.rules.egress.count // 0 | tostring)
      ]
    | @tsv
  '
) | column -t -s $'\t' | tee "$SG_BASIC_TABLE_FILE"
log "SG Basic table -> $SG_BASIC_TABLE_FILE"

SG_INGRESS_FILE="$SUMMARIES_DIR/scoutsuite_ingress_rules_${timestamp}.txt"
(
  echo -e "Region\tName\tSG ID\tProtocol\tPort Range\tSource Type\tSource Value"
  tail -n +2 "$SCOUT_FILE" | jq -r '
    .services.ec2.regions
    | to_entries[]
    | . as $regionEntry
    | $regionEntry.value.vpcs[]
    | .security_groups[]
    | select(type == "object")
    | . as $sg
    | $sg.rules.ingress.protocols
      | to_entries[]
      | .key as $protocol
      | .value.ports
      | to_entries[]
      | .key as $port_range
      | .value
      | (
          ( .cidrs[]? | [$regionEntry.key, $sg.name, $sg.id, $protocol, $port_range, "CIDR", .CIDR] ),
          ( .security_groups[]? | [$regionEntry.key, $sg.name, $sg.id, $protocol, $port_range, "Security Group", .GroupId] )
        )
      | @tsv
  ' 2>/dev/null
) | column -t -s $'\t' | tee "$SG_INGRESS_FILE"
log "Ingress rules -> $SG_INGRESS_FILE"

log "=== ScoutSuite Summary Complete ==="
log "Summaries in: $SUMMARIES_DIR"
log "Logs in: $LOGS_DIR"
log "Manifest file: $MANIFEST"
