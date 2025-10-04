import subprocess
import sys
import re

QUALYS_SSL_LABS_URL = "https://www.ssllabs.com/ssltest/analyze.html?d={}"

# Explicit sort order for protocols.
PROTOCOL_ORDER = {
    "TLSv1.3": 0,
    "TLSv1.2": 1,
    "TLSv1.1": 2,
    "TLSv1.0": 3,
    "SSLv3": 4,
    "SSLv2": 5
}

def run_sslscan(domain):
    """Runs sslscan and returns the raw output."""
    try:
        result = subprocess.run(
            ["sslscan", "--no-colour", domain],
            capture_output=True, text=True, check=True
        )
        return result.stdout
    except FileNotFoundError:
        print("❌ Error: `sslscan` is not installed. Install it and try again.")
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"❌ Error running `sslscan`: {e}")
        sys.exit(1)

def is_cipher_weak(cipher_name: str, tls_version: str) -> bool:
    """
    Qualys-like logic:
      - For TLSv1.3, ciphers are always strong.
      - For TLSv1.2 and below, check if the cipher uses ephemeral key exchange
        (ECDHE or DHE) and an AEAD algorithm (GCM, CHACHA, or POLY1305).
      - If both conditions are met, it is strong; otherwise, it's weak.
    """
    c = cipher_name.upper()
    if tls_version == "TLSv1.3":
        return False
    ephemeral = ("ECDHE" in c) or ("DHE" in c)
    aead = any(x in c for x in ["GCM", "CHACHA", "POLY1305"])
    return not (ephemeral and aead)

def parse_sslscan_output(output):
    """Parses sslscan output into a structured format."""
    parsed_data = {
        "TLS_Protocols": {},
        "Cipher_Suites": [],
        "Certificate": {}
    }

    # Extract TLS protocols.
    tls_pattern = re.compile(r"^(TLSv[\d\.]+|SSLv[\d\.]+)\s+(enabled|disabled)$", re.MULTILINE)
    for version, status in tls_pattern.findall(output):
        parsed_data["TLS_Protocols"][version] = status

    # Sort protocols using explicit order.
    parsed_data["TLS_Protocols"] = dict(sorted(
        parsed_data["TLS_Protocols"].items(),
        key=lambda item: PROTOCOL_ORDER.get(item[0], 99)
    ))

    # Extract Cipher Suites.
    cipher_pattern = re.compile(
        r"^(Preferred|Accepted)\s+(TLSv[\d\.]+)\s+\d+\s+bits\s+([A-Za-z0-9\-_]+)",
        re.MULTILINE
    )
    for match in cipher_pattern.findall(output):
        pref_or_acc, version, cipher = match
        weak = is_cipher_weak(cipher, version)
        parsed_data["Cipher_Suites"].append({
            "Version": version,
            "Cipher": cipher,
            "PreferredOrAccepted": pref_or_acc,
            "Weak": weak
        })

    # Extract Certificate Details.
    cert_pattern = re.compile(r"^\s*(Subject|Issuer):\s*(.+)$", re.MULTILINE)
    for match in cert_pattern.findall(output):
        key, value = match
        parsed_data["Certificate"][key] = value.strip()

    valid_from_pattern = re.search(r"Not valid before:\s*(.+)", output)
    valid_to_pattern = re.search(r"Not valid after:\s*(.+)", output)
    if valid_from_pattern:
        parsed_data["Certificate"]["Valid From"] = valid_from_pattern.group(1)
    if valid_to_pattern:
        parsed_data["Certificate"]["Valid To"] = valid_to_pattern.group(1)

    rsa_pattern = re.search(r"RSA Key Strength:\s*(\d+)", output)
    if rsa_pattern:
        parsed_data["Certificate"]["RSA Key Size"] = rsa_pattern.group(1) + " bits"

    return parsed_data

def display_results(parsed_data, domain):
    """Displays structured results in a readable format."""
    print("🔍 SSL/TLS Security Report\n")

    # TLS Protocol Support.
    print("🔹 TLS/SSL Protocol Support:")
    for version, status in parsed_data["TLS_Protocols"].items():
        # For older protocols, if disabled then that's good.
        if version in ["SSLv2", "SSLv3", "TLSv1.0", "TLSv1.1"]:
            indicator = "✅" if status == "disabled" else "❌"
        else:
            indicator = "✅" if status == "enabled" else "❌"
        print(f"   {indicator} {version} ({status.capitalize()})")

    # Cipher Suites.
    print("\n🔹 Cipher Suites:")
    for c in parsed_data["Cipher_Suites"]:
        prefix = c["PreferredOrAccepted"]
        if c["Weak"]:
            print(f"   ❌ WEAK {c['Version']} {c['Cipher']} ({prefix})")
        else:
            print(f"   ✅ Accepted {c['Version']} {c['Cipher']} ({prefix})")

    # SSL Certificate Details.
    print("\n🔹 SSL Certificate Details:")
    for key, value in parsed_data["Certificate"].items():
        print(f"   {key}: {value}")

    # Qualys Link.
    print("\n🔗 For a more detailed scan, visit:")
    print(f"   {QUALYS_SSL_LABS_URL.format(domain)}\n")

    # Mozilla Link.
    print("\n🔗 For server TLS configuration, visit:")
    print(f"   https://wiki.mozilla.org/Security/Server_Side_TLS\n")

    print("✅ Scan complete.\n")

def main():
    if len(sys.argv) != 2:
        print("\nUsage: python scan_ssl_tls.py <DOMAIN>")
        print("Example: python scan_ssl_tls.py www.yourdomain.com")
        sys.exit(1)

    domain = sys.argv[1]
    print(f"\n🔍 Running `sslscan` on {domain}...\n")

    raw_output = run_sslscan(domain)
    parsed_data = parse_sslscan_output(raw_output)
    display_results(parsed_data, domain)

if __name__ == "__main__":
    main()
