#!/bin/bash
# install-kics-queries.sh - Install KICS queries to system or local directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Install KICS queries for use with the scan-code.sh script.

OPTIONS:
  -l, --local     Install queries to local assets directory (default)
  -s, --system    Install queries to system directory (/usr/local/share/kics/assets/queries)
  -h, --help      Show this help message

EXAMPLES:
  $0                    # Install to local assets directory
  $0 --local           # Same as above
  $0 --system          # Install to system directory (requires sudo)

NOTES:
  - Local installation is recommended for this script
  - System installation requires root privileges
  - Queries are downloaded from https://github.com/Checkmarx/kics.git
EOF
    exit 1
}

install_local() {
    echo "Installing KICS queries to local directory..."
    
    local assets_dir="$SCRIPT_DIR/assets"
    mkdir -p "$assets_dir"
    cd "$assets_dir"
    
    if [[ -d "queries" ]]; then
        echo "Queries directory already exists. Updating..."
        rm -rf queries
    fi
    
    echo "Downloading KICS queries..."
    git clone --depth 1 https://github.com/Checkmarx/kics.git temp-kics
    cp -r temp-kics/assets/queries .
    rm -rf temp-kics
    
    echo "KICS queries installed to: $assets_dir/queries"
    echo "Found $(find "$assets_dir/queries" -name "*.rego" | wc -l) query files"
}

install_system() {
    echo "Installing KICS queries to system directory..."
    
    if [[ $EUID -ne 0 ]]; then
        echo "Error: System installation requires root privileges."
        echo "Please run: sudo $0 --system"
        exit 1
    fi
    
    local system_dir="/usr/local/share/kics/assets"
    mkdir -p "$system_dir"
    
    if [[ -d "$system_dir/queries" ]]; then
        echo "System queries directory already exists. Updating..."
        rm -rf "$system_dir/queries"
    fi
    
    echo "Downloading KICS queries to temporary directory..."
    cd /tmp
    rm -rf kics-install-temp
    git clone --depth 1 https://github.com/Checkmarx/kics.git kics-install-temp
    cp -r kics-install-temp/assets/queries "$system_dir/"
    rm -rf kics-install-temp
    
    echo "KICS queries installed to: $system_dir/queries"
    echo "Found $(find "$system_dir/queries" -name "*.rego" | wc -l) query files"
}

verify_dependencies() {
    if ! command -v git &> /dev/null; then
        echo "Error: git is required but not installed."
        echo "Please install git: sudo apt-get install git"
        exit 1
    fi
}

# Parse command line arguments
INSTALL_TYPE="local"

while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--local)
            INSTALL_TYPE="local"
            shift
            ;;
        -s|--system)
            INSTALL_TYPE="system"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Main execution
echo "KICS Queries Installer"
echo "======================"

verify_dependencies

case $INSTALL_TYPE in
    local)
        install_local
        ;;
    system)
        install_system
        ;;
esac

echo ""
echo "Installation complete!"
echo ""
echo "You can now run KICS scans using:"
echo "  ./scan-code.sh -r <repository> -t kics"
echo ""
echo "To verify the installation, run:"
echo "  ./scan-code.sh -r <repository> -t kics --dry-run 2>/dev/null || echo 'Test repository needed'"