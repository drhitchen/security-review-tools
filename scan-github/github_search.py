import os
import sys
import requests
import json
import time
import shutil
from dotenv import load_dotenv

# Load environment variables
load_dotenv()
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
GITHUB_API = os.getenv("GITHUB_ENTERPRISE", "https://api.github.com")

ORG_FILE = "github_orgs.json"
HEADERS = {
    "Authorization": f"Bearer {GITHUB_TOKEN}",
    "Accept": "application/vnd.github+json"
}

# Fetch rate limit status
def check_rate_limit():
    """Check GitHub API rate limits before making requests."""
    url = f"{GITHUB_API}/rate_limit"
    response = requests.get(url, headers=HEADERS)

    if response.status_code == 200:
        data = response.json()
        remaining = data["rate"]["remaining"]
        reset_time = int(data["rate"]["reset"])
        print(f"\U0001F6A6 API Rate Limit: {remaining} requests remaining. Resets at {reset_time}.")
        return remaining, reset_time
    else:
        print(f"⚠️ Could not retrieve rate limit: {response.status_code} - {response.text}")
        return 0, 0

# Fetch all organizations from GitHub if github_orgs.json is missing
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

# Load the list of GitHub organizations
def load_orgs():
    """Load GitHub organizations from file or fetch them if missing."""
    if not os.path.exists(ORG_FILE):
        print("⚠️ Org file missing. Fetching from GitHub...")
        return fetch_github_orgs()

    try:
        with open(ORG_FILE, "r") as f:
            return json.load(f)
    except Exception as e:
        print(f"❌ Error loading {ORG_FILE}: {e}")
        return fetch_github_orgs()

# Search across all orgs for the given query
def search_all_orgs(search_term):
    """Search GitHub API for a given search term across all orgs."""
    orgs = load_orgs()
    
    if not orgs:
        print("❌ No organizations found. Exiting.")
        exit(1)

    search_results = []
    requests_made = 0

    for org in orgs:
        if requests_made >= 9:
            print("⏳ Reached 9 requests, backing off for 65 seconds...")
            time.sleep(65)
            requests_made = 0

        url = f"{GITHUB_API}/search/code"
        params = {"q": f"org:{org} {search_term}", "per_page": 100}

        print(f"🔍 Searching for '{search_term}' in {org}...")
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
                results = response.json().get("items", [])
                search_results.extend(results)
                break

            elif response.status_code == 403:
                retries += 1
                sleep_time = 65 * (2 ** retries)
                print(f"⚠️ Rate limit hit. Retrying in {sleep_time} seconds...")
                time.sleep(sleep_time)
            else:
                print(f"❌ API Error: {response.status_code} - {response.text}")
                break

    filename = f"github_search_results_{search_term.replace(' ', '_')}.json"
    with open(filename, "w") as f:
        json.dump(search_results, f, indent=4)
    print(f"✅ Results saved: {filename}")
    parse_and_display_results(filename)

# Parse search results and display relevant information
def parse_and_display_results(filename):
    """Parse search results JSON and print organization/repository info."""
    try:
        with open(filename, "r") as f:
            data = json.load(f)
            if data:
                print("\n📋 Search Results:")
                for item in data:
                    print(f"🔹 Org: {item['repository']['owner']['login']}, Repo: {item['repository']['full_name']}")
            else:
                print("⚠️ No results found.")
    except Exception as e:
        print(f"❌ Error parsing results: {e}")

# Main execution
def main():
    """Main function to execute search or list orgs."""
    if len(sys.argv) < 2:
        orgs = load_orgs()
        print("\n📂 List of organizations:")
        for org in orgs:
            print(f"  - {org}")
        exit(0)
    
    search_term = " ".join(sys.argv[1:])
    search_all_orgs(search_term)

if __name__ == "__main__":
    main()
