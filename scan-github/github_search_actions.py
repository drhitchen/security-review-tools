#!/usr/bin/env python3

import os
import sys
import json
import time
import requests
import yaml
from dotenv import load_dotenv

# ------------------
# Environment Setup
# ------------------
load_dotenv()
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
GITHUB_API = os.getenv("GITHUB_ENTERPRISE", "https://api.github.com")

HEADERS = {
    "Authorization": f"Bearer {GITHUB_TOKEN}",
    "Accept": "application/vnd.github+json"
}

ORG_FILE = "github_orgs.json"
RESULTS_FILE = "third_party_actions_inventory.json"


# ------------------
# Helper Functions
# ------------------

def check_rate_limit():
    """Check GitHub API rate limit status before making requests."""
    url = f"{GITHUB_API}/rate_limit"
    response = requests.get(url, headers=HEADERS)
    if response.status_code == 200:
        data = response.json()
        remaining = data["rate"]["remaining"]
        reset_time = data["rate"]["reset"]
        print(f"Rate Limit: {remaining} remaining; resets at {reset_time}.")
        return remaining, reset_time
    else:
        print(f"⚠️ Could not retrieve rate limit: {response.status_code} - {response.text}")
        return 0, 0


def enforce_rate_limit():
    """Check rate limit, if exhausted, sleep until reset."""
    remaining, reset_time = check_rate_limit()
    if remaining == 0:
        # Sleep 65s or until the reset time (whichever is longer)
        sleep_time = max(reset_time - int(time.time()), 65)
        print(f"⏳ Rate limit exceeded. Sleeping for {sleep_time} seconds...")
        time.sleep(sleep_time)


def fetch_orgs():
    """Fetch all organizations for the authenticated user if missing."""
    url = f"{GITHUB_API}/user/orgs"
    response = requests.get(url, headers=HEADERS)
    if response.status_code == 200:
        orgs = [org["login"] for org in response.json()]
        with open(ORG_FILE, "w") as f:
            json.dump(orgs, f, indent=4)
        print(f"✅ Organizations saved to {ORG_FILE}")
        return orgs
    else:
        print(f"❌ Error fetching orgs: {response.status_code} - {response.text}")
        return []


def load_orgs():
    """Load GitHub organizations from file or fetch them if missing."""
    if not os.path.exists(ORG_FILE):
        print("⚠️ Org file missing. Fetching from GitHub...")
        return fetch_orgs()

    try:
        with open(ORG_FILE, "r") as f:
            return json.load(f)
    except Exception as e:
        print(f"❌ Error loading {ORG_FILE}: {e}")
        return fetch_orgs()


def fetch_all_repos(org):
    """
    Fetch all repositories in the specified organization.
    Paginates through results if there are many repositories.
    """
    print(f"🔎 Fetching repositories for org: {org}")
    repos = []
    page = 1

    while True:
        enforce_rate_limit()
        url = f"{GITHUB_API}/orgs/{org}/repos"
        params = {
            "type": "all",
            "per_page": 100,
            "page": page
        }
        response = requests.get(url, headers=HEADERS, params=params)

        if response.status_code != 200:
            print(f"❌ Error fetching repos for {org}: {response.status_code} - {response.text}")
            break

        batch = response.json()
        if not batch:
            break

        repos.extend(batch)
        page += 1

    return repos


def fetch_workflow_files(org, repo_name):
    """
    List all files in the `.github/workflows` directory of a given repo.
    Returns a list of file paths (with the API download URLs).
    """
    print(f"    📂 Checking workflows in {org}/{repo_name}")
    files = []
    enforce_rate_limit()

    # The `.github/workflows` path in the repo tree can be accessed via the Git Contents API
    url = f"{GITHUB_API}/repos/{org}/{repo_name}/contents/.github/workflows"
    response = requests.get(url, headers=HEADERS)

    # If there's no workflows directory or the repo is empty, we skip
    if response.status_code == 404:
        return files  # No workflows folder
    if response.status_code != 200:
        print(f"    ❌ Error fetching workflows for {org}/{repo_name}: {response.status_code} - {response.text}")
        return files

    directory_items = response.json()
    # directory_items could be a list if the folder exists. Validate structure:
    if isinstance(directory_items, list):
        for item in directory_items:
            if item["type"] == "file":
                files.append({
                    "name": item["name"],
                    "path": item["path"],
                    "download_url": item["download_url"]
                })
    return files


def parse_workflow_file(download_url):
    """
    Download and parse a workflow file from a given URL. Returns a list of 'uses' references found.
    """
    enforce_rate_limit()
    response = requests.get(download_url, headers=HEADERS)
    if response.status_code != 200:
        # If we cannot fetch it, skip
        return []

    try:
        content = response.text
        workflow_data = yaml.safe_load(content)
    except Exception as e:
        print(f"      ⚠️ Could not parse YAML: {e}")
        return []

    # If the workflow file doesn’t parse as valid YAML (or has no 'jobs'), we get none
    if not isinstance(workflow_data, dict):
        return []

    uses_references = []

    # workflows are generally structured:
    # jobs:
    #   some_job:
    #       steps:
    #         - uses: ...
    #         - run: ...
    jobs = workflow_data.get("jobs", {})
    if isinstance(jobs, dict):
        for job_name, job_data in jobs.items():
            steps = job_data.get("steps", [])
            if isinstance(steps, list):
                for step in steps:
                    if isinstance(step, dict) and "uses" in step:
                        uses_references.append(step["uses"])
    return uses_references


def is_third_party(action_ref, own_orgs):
    """
    Heuristic to determine if an action reference is third-party.
    We consider something third-party if:
      - It's not a built-in like 'actions/checkout' or 'actions/setup-node'.
      - It's not referencing your own organizations if you want to exclude them.
      - It typically has the form: <owner>/<repo>@<version>
    This logic can be customized further.
    """
    # Example: actions/checkout@v2 -> not third-party
    #          myorg/some-custom-action@v1 -> possibly first-party if myorg is in own_orgs
    #          random-user/random-action@v3 -> third-party

    # Normalize
    action_ref = action_ref.lower().strip()

    # Skip official GitHub-maintained actions:
    if action_ref.startswith("actions/"):
        return False

    # Extract the assumed 'owner' from <owner>/<repo>@ver
    parts = action_ref.split("@")[0].split("/")
    if not parts:
        return False  # We can't parse it, default to not labeling it third-party.

    owner = parts[0]
    return owner not in own_orgs and owner != "docker"  # Some folks do 'docker://...' references.


def main():
    if not GITHUB_TOKEN:
        print("❌ GITHUB_TOKEN not set. Please define it in your .env or environment.")
        sys.exit(1)

    orgs = load_orgs()
    if not orgs:
        print("❌ No organizations found. Exiting.")
        sys.exit(1)

    # So we can mark them as first-party if used from these orgs:
    # (In many shops, you only label your official GitHub org or GitHub user as first-party.)
    my_orgs_lower = [o.lower() for o in orgs]

    # Results data structure:
    # {
    #   "org_name": {
    #       "repo_name": [
    #           {
    #             "workflow_file": "some-workflow.yml",
    #             "uses_reference": "repo/action@v2",
    #             "is_third_party": True/False
    #           },
    #           ...
    #       ]
    #   },
    #   ...
    # }
    results = {}

    for org in orgs:
        repos = fetch_all_repos(org)
        if not repos:
            print(f"❌ No repositories found in org {org} or error occurred.")
            continue

        org_results = {}
        for repo in repos:
            repo_name = repo["name"]
            workflow_files = fetch_workflow_files(org, repo_name)

            if not workflow_files:
                continue

            repo_inventory = []
            for wf in workflow_files:
                uses_list = parse_workflow_file(wf["download_url"])
                for action_ref in uses_list:
                    data_entry = {
                        "workflow_file": wf["path"],
                        "uses_reference": action_ref,
                        "is_third_party": is_third_party(action_ref, my_orgs_lower)
                    }
                    repo_inventory.append(data_entry)

            if repo_inventory:
                org_results[repo_name] = repo_inventory

        if org_results:
            results[org] = org_results

    # Save to JSON
    with open(RESULTS_FILE, "w") as f:
        json.dump(results, f, indent=4)

    print(f"\n✅ Inventory complete. Results saved to {RESULTS_FILE}")

    # Optional: Print a brief summary of third-party actions
    print("\n=== Third-Party Actions Found ===")
    third_party_count = 0
    for org, repos_data in results.items():
        for repo_name, entries in repos_data.items():
            for e in entries:
                if e["is_third_party"]:
                    print(f"{org}/{repo_name}: {e['uses_reference']} (file: {e['workflow_file']})")
                    third_party_count += 1
    print(f"Total third-party references found: {third_party_count}")


if __name__ == "__main__":
    main()
