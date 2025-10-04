#!/usr/bin/env python3
import os
import sys
import re
import time
import json
import requests
from dotenv import load_dotenv
import base64

# Load environment variables
load_dotenv()
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
GITHUB_API = os.getenv("GITHUB_ENTERPRISE", "https://api.github.com")

ORG_FILE = "github_orgs.json"
RESULTS_FILE = "nextjs_versions.json"
# Use text-match header to get code fragments in results
HEADERS = {
    "Authorization": f"Bearer {GITHUB_TOKEN}",
    "Accept": "application/vnd.github.v3.text-match+json"
}

def check_rate_limit():
    """Check GitHub API rate limits."""
    url = f"{GITHUB_API}/rate_limit"
    response = requests.get(url, headers=HEADERS)
    if response.status_code == 200:
        data = response.json()
        remaining = data["rate"]["remaining"]
        reset_time = int(data["rate"]["reset"])
        print(f"⏱  API Rate Limit: {remaining} requests remaining. Resets at {reset_time}.")
        return remaining, reset_time
    else:
        print(f"⚠️  Error checking rate limit: {response.status_code} - {response.text}")
        return 0, 0

def fetch_github_orgs():
    """Fetch all organizations associated with the authenticated user."""
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
        print("⚠️  Org file missing. Fetching from GitHub...")
        return fetch_github_orgs()
    try:
        with open(ORG_FILE, "r") as f:
            return json.load(f)
    except Exception as e:
        print(f"❌ Error loading {ORG_FILE}: {e}")
        return fetch_github_orgs()

def search_all_orgs(search_query):
    """Search all orgs for the specified query and extract next.js version info."""
    orgs = load_orgs()
    if not orgs:
        print("❌ No organizations found. Exiting.")
        sys.exit(1)

    all_results = []
    requests_made = 0

    for org in orgs:
        # Rate-limit safeguard: back off after ~9 requests
        if requests_made >= 9:
            print("⏳ Reached 9 requests, backing off for 65 seconds...")
            time.sleep(65)
            requests_made = 0

        url = f"{GITHUB_API}/search/code"
        params = {"q": f"org:{org} {search_query}", "per_page": 100}
        print(f"🔍 Searching for next.js declarations in package.json in org '{org}'...")
        retries = 0
        max_retries = 5

        while retries < max_retries:
            remaining, reset_time = check_rate_limit()
            if remaining == 0:
                sleep_time = max(reset_time - int(time.time()), 65)
                print(f"⏳ Rate limit exceeded. Sleeping for {sleep_time} seconds...")
                time.sleep(sleep_time)
                retries += 1

            response = requests.get(url, headers=HEADERS, params=params)
            requests_made += 1

            if response.status_code == 200:
                items = response.json().get("items", [])
                for item in items:
                    entry = extract_nextjs_version(item)
                    if entry:
                        all_results.append(entry)
                break  # exit retry loop on success
            elif response.status_code == 403:
                retries += 1
                sleep_time = 65 * (2 ** retries)
                print(f"⚠️  Rate limit hit. Retrying in {sleep_time} seconds...")
                time.sleep(sleep_time)
            else:
                print(f"❌ API Error: {response.status_code} - {response.text}")
                break

    with open(RESULTS_FILE, "w") as f:
        json.dump(all_results, f, indent=4)
    print(f"✅ Results saved to {RESULTS_FILE}")
    print_summary(all_results)

def extract_nextjs_version(item):
    repo = item["repository"]["full_name"]
    org = item["repository"]["owner"]["login"]
    file_path = item["path"]
    html_url = item["html_url"]
    version = None

    file_api_url = item.get("url")
    if file_api_url:
        r = requests.get(file_api_url, headers={"Authorization": f"Bearer {GITHUB_TOKEN}"})
        if r.status_code == 200:
            try:
                content_json = r.json()
                if "content" in content_json and content_json.get("encoding") == "base64":
                    decoded = base64.b64decode(content_json["content"]).decode("utf-8")
                    pkg = json.loads(decoded)
                    deps = pkg.get("dependencies", {})
                    version = deps.get("next")
            except Exception as e:
                print(f"⚠️ Error parsing {repo}/{file_path}: {e}")

    if version:
        return {
            "org": org,
            "repo": repo,
            "file": file_path,
            "version": version,
            "html_url": html_url
        }
    return None

def print_summary(results):
    """Print a summary of next.js versions found."""
    print("\n=== Next.js Versions Audit Summary ===")
    if not results:
        print("No next.js usage found.")
        return

    version_counts = {}
    for entry in results:
        ver = entry["version"]
        version_counts[ver] = version_counts.get(ver, 0) + 1

    for ver, count in version_counts.items():
        print(f"Version {ver}: {count} occurrence(s)")
    print(f"\nTotal occurrences found: {len(results)}")

def main():
    # Fixed query to locate package.json files with a next.js dependency
    search_query = 'filename:package.json "next":'
    search_all_orgs(search_query)

if __name__ == "__main__":
    main()
