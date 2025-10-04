import os
import sys
import json
import webbrowser
import requests
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

# Fetch and save organizations from GitHub
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

# Load or generate the list of GitHub organizations
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

# Split search queries to stay within GitHub's 256-character limit
def split_search_queries(orgs, search_term, max_length=200):
    """Split org search queries into multiple searches under the character limit."""
    search_queries = []
    current_query = []
    current_length = len(search_term) + 1  # Including space

    for org in orgs:
        org_part = f"org:{org} OR "
        if current_length + len(org_part) > max_length:
            search_queries.append(" ".join(current_query)[:-3])  # Remove trailing OR
            current_query = [org_part]
            current_length = len(search_term) + len(org_part) + 1
        else:
            current_query.append(org_part)
            current_length += len(org_part)
    
    if current_query:
        search_queries.append(" ".join(current_query)[:-3])  # Remove trailing OR
    
    return search_queries

# Open GitHub search queries in browser
def open_github_search(orgs, search_term):
    """Open multiple GitHub search queries in separate browser tabs."""
    search_queries = split_search_queries(orgs, search_term)
    
    for query in search_queries:
        encoded_query = query.replace(" ", "+")
        search_url = f"https://github.com/search?q={encoded_query}+{search_term.replace(' ', '+')}&type=code"
        print(f"\n🔍 Opening GitHub Search: {search_url}")
        webbrowser.open_new_tab(search_url)

def main():
    orgs = load_orgs()
    
    if not orgs:
        print("❌ No organizations found. Exiting.")
        exit(1)

    if len(sys.argv) < 2:
        print("\n📂 List of organizations:")
        for org in orgs:
            print(f"  - {org}")
        exit(0)

    search_term = " ".join(sys.argv[1:])
    open_github_search(orgs, search_term)

if __name__ == "__main__":
    main()
