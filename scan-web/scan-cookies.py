import time
import json
import sys
import datetime
from tabulate import tabulate
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager

def format_expiry(expiry):
    """Convert Unix timestamp to human-readable date, or return 'Session'."""
    if expiry == "Session" or expiry is None:
        return "Session Cookie"
    try:
        return datetime.datetime.fromtimestamp(expiry, datetime.UTC).strftime('%Y-%m-%d %H:%M:%S')
    except (ValueError, OSError):
        return "Invalid Expiry"

def identify_cookie_type(name):
    """Identify likely purpose of a cookie based on its name."""
    if name.startswith(("_ga", "_gid", "_gat", "__utma", "__utmb", "__utmz")):
        return "Analytics (Google Analytics)"
    elif name.startswith(("_hjid", "_hjSessionUser", "_hjFirstSeen", "_hjAbsoluteSessionInProgress")):
        return "Analytics (Hotjar)"
    elif name.startswith(("_fbp", "_fbc", "fr")):
        return "Marketing (Facebook)"
    elif name.startswith(("PHPSESSID", "JSESSIONID", "ASPSESSIONID", "ASP.NET_SessionId", "SESS")):
        return "Session Management"
    elif name.startswith(("csrftoken", "_csrf", "XSRF-TOKEN")):
        return "Security (CSRF Protection)"
    elif name.startswith(("AWSALB", "AWSALBCORS")):
        return "Load Balancing"
    elif name.startswith(("incap_ses_", "visid_incap_", "nlbi_")):
        return "Security/CDN (Imperva)"
    elif name.startswith(("cf_", "__cf", "cloudflare")):
        return "Security/CDN (Cloudflare)"
    elif name.startswith(("ak_bmsc", "bm_sz", "_abck")):
        return "Security/CDN (Bot Detection)"
    elif name.startswith(("auth_", "token", "jwt", "remember_", "login_", "user_", "session_", "id_token", "access_token")):
        return "Authentication"
    elif "consent" in name.lower():
        return "Cookie Consent"
    elif "tracking" in name.lower():
        return "Tracking/Marketing"
    else:
        return "Unknown"

# Check for command-line arguments
if len(sys.argv) != 2:
    print("\nUsage: python analyze_cookies.py <URL>")
    print("Example: python analyze_cookies.py https://www.yourdomain.com")
    sys.exit(1)

# Get URL from argument
url = sys.argv[1]

# Setup Selenium with headless Chrome
options = Options()
options.add_argument("--headless")  # Run in headless mode
options.add_argument("--disable-gpu")  # Disable GPU for headless mode stability
options.add_argument("--no-sandbox")  # Avoid issues in some environments
options.add_argument("--disable-dev-shm-usage")  # Prevent crashes in Docker
options.add_argument("--window-size=1920,1080")  # Set standard window size
options.add_argument("--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36")

# Initialize the WebDriver
service = Service(ChromeDriverManager().install())
driver = webdriver.Chrome(service=service, options=options)

print(f"\n🔍 Analyzing cookies for: {url}")

# Open the website
driver.get(url)

# Allow JavaScript to execute
time.sleep(3)

# Extract cookies
cookies = driver.get_cookies()

# Close the browser
driver.quit()

# Header
print("\n" + "=" * 50)
print("                 COOKIE SECURITY ANALYSIS")
print("=" * 50 + "\n")

# Security analysis
secure_count = 0
httponly_count = 0
samesite_count = 0
total_cookies = len(cookies)

cookie_data = []
table_data = []

for cookie in cookies:
    name = cookie['name']
    domain = cookie['domain']
    path = cookie['path']
    secure = "✅ Yes" if cookie['secure'] else "❌ No"
    httponly = "✅ Yes" if cookie.get('httpOnly', False) else "❌ No"
    expiry = format_expiry(cookie.get('expiry', 'Session'))
    samesite = cookie.get('sameSite', 'Not Set')
    likely_purpose = identify_cookie_type(name)

    # Increment security counters
    if secure == "✅ Yes":
        secure_count += 1
    if httponly == "✅ Yes":
        httponly_count += 1
    if samesite != "Not Set":
        samesite_count += 1

    # Print detailed per-cookie security information with emojis
    print(f"🍪 Cookie: {name}")
    print(f"  🔹 Domain: {domain}")
    print(f"  🔹 Path: {path}")
    print(f"  🔹 Secure: {secure}")
    print(f"  🔹 HttpOnly: {httponly}")
    print(f"  🔹 SameSite: {samesite}")
    print(f"  🔹 Expiry: {expiry}")
    print(f"  🔹 Likely Purpose: {likely_purpose}\n")

    # Store data for JSON output
    cookie_data.append({
        "name": name,
        "domain": domain,
        "path": path,
        "secure": secure,
        "httponly": httponly,
        "samesite": samesite,
        "expiry": expiry,
        "likely_purpose": likely_purpose
    })

    # Store data for summary table (without emojis for clean formatting)
    table_data.append([name, domain, "Yes" if "✅" in secure else "No", 
                       "Yes" if "✅" in httponly else "No", samesite, expiry])

# Summary Table
print("=" * 50)
print("                 COOKIES SUMMARY TABLE")
print("=" * 50 + "\n")

# Format table
headers = ["Cookie Name", "Domain", "Secure", "HttpOnly", "SameSite", "Expiry"]
print(tabulate(table_data, headers=headers, tablefmt="grid"))

# Security Recommendations
print("\n" + "=" * 50)
print("                 SECURITY RECOMMENDATIONS")
print("=" * 50 + "\n")

if secure_count < total_cookies:
    print("⚠️  Set the Secure flag on all cookies to prevent transmission over HTTP.")
if httponly_count < total_cookies:
    print("⚠️  Set the HttpOnly flag to prevent JavaScript access to cookies.")
if samesite_count < total_cookies:
    print("⚠️  Set the SameSite attribute (Lax or Strict recommended) to prevent CSRF attacks.")

print("\n✅ Analysis complete.")
json_filename = "cookies_analysis.json"

# Save to JSON file
with open(json_filename, "w") as json_file:
    json.dump(cookie_data, json_file, indent=4)

print(f"📂 Cookie data saved to `{json_filename}`.")
