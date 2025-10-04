# GitHub Enterprise Organization Search Tools

## Overview

This repository contains Python scripts for searching across GitHub organizations within an enterprise setup. These tools provide multiple ways to search for code within GitHub Enterprise organizations using the GitHub API or a web browser.

## Features

- **Search:** Search for a term across all GitHub organizations.
- **Browser Search:** Opens GitHub UI search results in a web browser for manual verification.
- **GitHub Actions Inventory:** Scans repositories to identify third-party GitHub Actions usage.
- **Next.js Audit:** Scan all package.json files for vulnerable Next.js versions.
- **Rate Limit Handling:** Implements rate limit checks and exponential backoff for API requests.
- **Environment Configuration:** Uses `.env` variables for GitHub authentication and API endpoint configuration.

## Project Structure

```
scan-github
├── github_search.py                  # Searches GitHub organizations for a given term using the GitHub API
├── github_search_actions.py          # Scans repositories for GitHub Actions used in workflows
├── github_search_browser.py          # Opens GitHub search results in a web browser for manual verification
├── github_audit_nextjs.py            # Audits Next.js version usage in package.json
├── requirements.txt                  # Required Python dependencies - install via `pip install -r requirements.txt`
└── README.md                         # Project documentation and usage instructions
```

## Requirements

The scripts require Python and the following dependencies:

```
python-dotenv
pyyaml
requests
```

### Setup Virtual Environment (Recommended)

```sh
python -m venv venv
source venv/bin/activate  # On Windows use `venv\Scripts\activate`
pip install -r requirements.txt
```

## Environment Configuration

Create a `.env` file in the project root with the following:

```ini
GITHUB_TOKEN=<your_github_personal_access_token>
GITHUB_ENTERPRISE=https://api.github.com
```

## Usage

### 1. Search GitHub Orgs for Any Term

```sh
python github_search.py "search term"
```

### 2. Open Browser-Based GitHub Searches

```sh
python github_search_browser.py "search term"
```

### 3. Inventory GitHub Actions Across All Repos

```sh
python github_search_actions.py
```

### 4. Audit Next.js Usage Across GitHub Repos

```sh
python github_audit_nextjs.py
```

- Searches for `next` dependencies in `package.json`.
- Results saved to `nextjs_versions.json`.

#### Example Output

```
=== Next.js Versions Audit Summary ===
Version 15.2.4: 6 occurrence(s)
Version ^14.2.28: 1 occurrence(s)
...
Total occurrences found: 30
```

### Patched Next.js Versions

| Version Branch | Fixed Version |
|----------------|----------------|
| 15.x           | 15.2.3         |
| 14.x           | 14.2.25        |
| 13.x           | 13.5.9         |
| 12.x           | 12.3.5         |

## `jq` Analysis for Next.js Audit

#### Count of Versions per Repo

```bash
jq -r '
group_by(.repo)[] |
{
  repo: .[0].repo,
  versions: ([.[].version] | unique | join(", ")),
  count: length
} |
[.repo, .versions, (.count|tostring)] |
@tsv
' nextjs_versions.json | column -t
```

#### Count of Repos per Version

```bash
jq '[.[] | {repo, version}] | group_by(.version) | map({
  version: .[0].version,
  repo_count: length,
  repos: [.[].repo] | unique
})' nextjs_versions.json
```

#### Flag Version as Good / OK / Bad

```bash
jq -r '
def parse_ver($v):
  $v | sub("^\\^"; "") | sub("-.*$"; "") | split(".") + ["0","0","0"] | .[0:3] | map(tonumber);

def is_gte14($v): (parse_ver($v) as $ver | [14,2,25] as $base |
  $ver[0] == 14 and ($ver[1] > $base[1] or ($ver[1] == $base[1] and $ver[2] >= $base[2]))
);

def is_gte15($v): (parse_ver($v) as $ver | [15,2,3] as $base |
  $ver[0] == 15 and ($ver[1] > $base[1] or ($ver[1] == $base[1] and $ver[2] >= $base[2]))
);

def status_for($v):
  if $v == "*" then "BAD"
  elif is_gte15($v) or is_gte14($v) then "GOOD"
  else "BAD" end;

[.[] | {
  repo,
  version,
  status: (
    if .version | test("^\\^") then
      if status_for(.version | sub("^\\^"; "")) == "GOOD" then "OK" else "BAD" end
    else
      status_for(.version)
    end
  )
}] | sort_by(.repo) | .[] | [.repo, .version, .status] | @tsv' nextjs_versions.json | column -t
```

### Dependency Syntax Notes

| Syntax    | Meaning                     | Risk       |
|-----------|-----------------------------|------------|
| "15.2.3"  | Exact version               | ✅ Safe     |
| "^15.2.3" | 15.2.3 ≤ v < 16.0.0         | ⚠️ Drift    |
| "*"       | Any version at all          | 🔥 High Risk|

📌 Caret (^) allows upgrades within the same major version.

📌 Asterisk (*) accepts all versions, including old or prerelease.

✅ Recommendation: Pin production dependencies to exact versions.

## API Rate Limit Handling

All scripts include rate limit checks and backoff with retries to avoid GitHub API throttling.

## Organization Management

All scripts use `github_orgs.json` to track orgs available to your token.

- Delete it to force refresh.
- Run any script with no args to list orgs.

## `jq` Tips for GitHub Actions Inventory

#### Unique Actions Without Versions

```bash
jq '.[].[].[].uses_reference | split("@")[0]' third_party_actions_inventory.json | sort -u
```

#### Unique Actions With Versions

```bash
jq '.[].[].[].uses_reference' third_party_actions_inventory.json | sort -u
```

#### Count Action Usage

```bash
jq '.[].[].[].uses_reference' third_party_actions_inventory.json | sort | uniq -c | sort -nr
```

## Security Considerations

- Never commit `.env` files with secrets.
- Treat results from private repos as sensitive.
- Regular audits can reduce supply chain risk.

## License

See the [LICENSE](../LICENSE) file for details.

## Author

Developed by **Doug Hitchen** ([GitHub](https://github.com/drhitchen)).
