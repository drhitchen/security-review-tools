#!/bin/bash
# recon-account.sh - Extract AWS account information using AWS CLI tools

# Increase file descriptor limit to prevent "Too many open files" errors
ulimit -Sn 1000

###############################################################################
# Usage & Argument Parsing
###############################################################################

usage() {
    cat <<EOF
Usage: $0 [-a aws_account] [-p aws_profile] [-o output_directory]
  -a aws_account   AWS account number (or set AWS_ACCOUNT in .env)
  -p aws_profile   AWS CLI profile (default: default)
  -o output_dir    Base output directory (default: ./output)
EOF
    exit 1
}

while getopts "a:p:o:" opt; do
    case $opt in
        a) account_opt="$OPTARG" ;;
        p) profile_opt="$OPTARG" ;;
        o) output_opt="$OPTARG" ;;
        *) usage ;;
    esac
done

###############################################################################
# Environment Setup
###############################################################################

# Load environment variables from .env if available
if [ -f ".env" ]; then
    echo "Loading settings from .env"
    source ".env"
fi

AWS_ACCOUNT="${account_opt:-$AWS_ACCOUNT}"
if [ -z "$AWS_ACCOUNT" ]; then
    echo "Error: AWS account not specified."
    usage
fi

AWS_PROFILE="${profile_opt:-${AWS_PROFILE:-default}}"

# We'll store results under output/account-scans/<AWS_ACCOUNT>/scans/recon
OUTPUT_ROOT="${output_opt:-$(pwd)/output}/account-scans"
ACCOUNT_DIR="$OUTPUT_ROOT/$AWS_ACCOUNT"
SCANS_DIR="$ACCOUNT_DIR/scans"
RECON_DIR="$SCANS_DIR/recon"
SUMMARIES_DIR="$ACCOUNT_DIR/summaries"
LOGS_DIR="$ACCOUNT_DIR/logs"

# Create subdirectories
mkdir -p "$SCANS_DIR" "$RECON_DIR" "$SUMMARIES_DIR" "$LOGS_DIR"

TIMESTAMP=$(date +%Y%m%d%H%M%S)
MANIFEST="$LOGS_DIR/recon_manifest_${TIMESTAMP}.log"

###############################################################################
# Logging Function
###############################################################################

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$MANIFEST"
}

###############################################################################
# AWS Recon Functions
###############################################################################

get_region_status() {
    log "Fetching AWS region statuses..."
    REGION_STATUS_FILE="$RECON_DIR/region-status_${TIMESTAMP}.txt"
    REGIONS_JSON=$(aws account list-regions --profile "$AWS_PROFILE" --output json)

    ENABLED_REGIONS=$(echo "$REGIONS_JSON" | jq -r '.Regions[] | select(.RegionOptStatus | test("ENABLED")) | .RegionName')
    DISABLED_REGIONS=$(echo "$REGIONS_JSON" | jq -r '.Regions[] | select(.RegionOptStatus == "DISABLED") | .RegionName')

    {
        echo "Enabled Regions:"
        echo "$ENABLED_REGIONS"
        echo ""
        echo "Disabled Regions:"
        echo "$DISABLED_REGIONS"
    } | tee "$REGION_STATUS_FILE" | tee -a "$MANIFEST"
}

get_all_sgs_consolidated() {
    log "Fetching security groups for enabled regions..."
    SG_ALL_FILE="$RECON_DIR/sg_all_${TIMESTAMP}.txt"

    # Get list of available regions
    REGIONS=($(aws ec2 describe-regions \
        --query "Regions[].RegionName" \
        --profile "$AWS_PROFILE" \
        --output text))

    for region in "${REGIONS[@]}"; do
        header="### REGION: $region ###"
        echo "$header" | tee -a "$SG_ALL_FILE"
        echo "" | tee -a "$SG_ALL_FILE"

        # Fetch SGs for the region
        sg_json=$(aws ec2 describe-security-groups \
            --region "$region" \
            --profile "$AWS_PROFILE" \
            --no-cli-pager)

        echo "$sg_json" | tee -a "$SG_ALL_FILE"
        echo "" | tee -a "$SG_ALL_FILE"
    done
}

get_iam_summary() {
    log "Fetching IAM roles, policies, and users..."
    IAM_FILE="$RECON_DIR/iam_summary_${TIMESTAMP}.txt"

    {
        echo "### IAM Users ###"
        USERS_JSON=$(aws iam list-users --profile "$AWS_PROFILE" --output json 2>&1)
        echo "$USERS_JSON" | tee "$RECON_DIR/iam_users_raw_${TIMESTAMP}.json"
        
        if echo "$USERS_JSON" | jq -e '.Users | length > 0' >/dev/null 2>&1; then
            echo "$USERS_JSON" | jq -r '.Users[] | {UserName, UserId, CreateDate}'
        else
            echo "No IAM users found."
        fi

        echo ""
        echo "### IAM Roles ###"
        ROLES_JSON=$(aws iam list-roles --profile "$AWS_PROFILE" --output json 2>&1)
        echo "$ROLES_JSON" | tee "$RECON_DIR/iam_roles_raw_${TIMESTAMP}.json"

        if echo "$ROLES_JSON" | jq -e '.Roles | length > 0' >/dev/null 2>&1; then
            echo "$ROLES_JSON" | jq -r '.Roles[] | {RoleName, RoleId, CreateDate}'
        else
            echo "No IAM roles found."
        fi

        echo ""
        echo "### IAM Policies ###"
        POLICIES_JSON=$(aws iam list-policies --scope Local --profile "$AWS_PROFILE" --output json 2>&1)
        echo "$POLICIES_JSON" | tee "$RECON_DIR/iam_policies_raw_${TIMESTAMP}.json"

        if echo "$POLICIES_JSON" | jq -e '.Policies | length > 0' >/dev/null 2>&1; then
            echo "$POLICIES_JSON" | jq -r '.Policies[] | {PolicyName, PolicyId, CreateDate}'
        else
            echo "No IAM policies found."
        fi
    } | tee "$IAM_FILE" | tee -a "$MANIFEST"
}

get_network_summary() {
    log "Fetching VPC, subnet, and route table details..."
    NETWORK_FILE="$RECON_DIR/network_summary_${TIMESTAMP}.txt"

    {
        echo "### VPCs ###"
        aws ec2 describe-vpcs --profile "$AWS_PROFILE" --output json | jq -r '.Vpcs[] | {VpcId, CidrBlock, State}'

        echo ""
        echo "### Subnets ###"
        aws ec2 describe-subnets --profile "$AWS_PROFILE" --output json | jq -r '.Subnets[] | {SubnetId, VpcId, CidrBlock, AvailabilityZone}'

        echo ""
        echo "### Route Tables ###"
        aws ec2 describe-route-tables --profile "$AWS_PROFILE" --output json | jq -r '.RouteTables[] | {RouteTableId, VpcId, Routes}'
    } | tee "$NETWORK_FILE" | tee -a "$MANIFEST"
}

###############################################################################
# Main Execution Block
###############################################################################

log "=== Recon Started ==="
log "Parameters:"
log "  AWS Account      : $AWS_ACCOUNT"
log "  AWS Profile      : $AWS_PROFILE"
log "  Output Directory : $OUTPUT_ROOT"

# Role assumption: if AWS_ROLE is set, assume it
if [ -n "$AWS_ROLE" ]; then
    ROLE_SESSION="${AWS_ROLE_SESSION_NAME:-scanAccountSession}"
    log "Attempting to assume role: $AWS_ROLE with session name: $ROLE_SESSION"
    credentials=$(aws --profile "$AWS_PROFILE" sts assume-role \
        --role-arn "$AWS_ROLE" \
        --role-session-name "$ROLE_SESSION" \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
        --output text 2>&1)
    if [ $? -ne 0 ]; then
        log "Error assuming role: $credentials"
        exit 1
    fi
    export AWS_ACCESS_KEY_ID=$(echo "$credentials" | awk '{print $1}')
    export AWS_SECRET_ACCESS_KEY=$(echo "$credentials" | awk '{print $2}')
    export AWS_SESSION_TOKEN=$(echo "$credentials" | awk '{print $3}')
    log "Assumed role successfully. AWS_ACCESS_KEY_ID updated."
fi

get_region_status
get_all_sgs_consolidated
get_iam_summary
get_network_summary

SUMMARY="=== Recon Summary ===\n"
SUMMARY+="Region status written to: $RECON_DIR/region-status_${TIMESTAMP}.txt\n"
SUMMARY+="All security groups written to: $RECON_DIR/sg_all_${TIMESTAMP}.txt\n"
SUMMARY+="IAM Summary written to: $RECON_DIR/iam_summary_${TIMESTAMP}.txt\n"
SUMMARY+="Network Summary written to: $RECON_DIR/network_summary_${TIMESTAMP}.txt\n"

log "$SUMMARY"
log "=== Recon Complete ==="

log "Raw recon data in: $RECON_DIR"
log "Logs in: $LOGS_DIR"
log "Manifest file: $MANIFEST"
