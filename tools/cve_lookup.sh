#!/usr/bin/env bash

# cve_lookup function
cve_lookup() {
  # Usage examples:
  #   cve_lookup CVE-2022-29248
  #   cve_lookup CVE-2022-29248 CVE-2022-31042
  #   cve_lookup "CVE-2022-29248,CVE-2022-31042"
  #   cve_lookup CVE-2022-29248, CVE-2022-31042

  if [ $# -eq 0 ]; then
    echo "Usage: cve_lookup <CVE1> [<CVE2> ...], or 'CVE1,CVE2,...'"
    return 1
  fi

  # For each argument (which may have multiple CVEs separated by commas)
  for arg in "$@"; do
    # Replace commas with spaces
    for cve_id in $(echo "$arg" | tr ',' ' '); do
      echo "----- [ $cve_id ] -----"

      # Perform the curl request to fetch JSON
      local response
      response="$(curl -s "https://cveawg.mitre.org/api/cve/$cve_id")"

      # 1) Extract the main English description from the JSON
      local description
      description="$(echo "$response" | jq -r '.containers.cna.descriptions[0].value' 2>/dev/null)"

      if [[ -z "$description" || "$description" == "null" ]]; then
        echo "No information found or invalid CVE."
        echo
        continue
      fi

      echo "Description: $description"

      # 2) Extract CVSS data (version 3.1) if present in any 'metrics' entry
      #    We'll collect them all and print each one.
      local cvss_data
      cvss_data="$(echo "$response" | jq -r '
        .containers.cna.metrics[]? 
        | select(.cvssV3_1 != null) 
        | "Base Score: \(.cvssV3_1.baseScore) (\(.cvssV3_1.baseSeverity))\nVector: \(.cvssV3_1.vectorString)\n"
      ' 2>/dev/null)"

      if [[ -n "$cvss_data" ]]; then
        echo
        echo "CVSS v3.1 Details:"
        echo "$cvss_data"
      fi

      echo
    done
  done
}

################################################################################
# If the script is run directly (not sourced), call cve_lookup with any params.
################################################################################
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  if [ $# -gt 0 ]; then
    cve_lookup "$@"
  else
    echo "Usage: $0 <CVE1> [<CVE2> ...], or '$0 CVE1,CVE2,...'"
    exit 1
  fi
fi
