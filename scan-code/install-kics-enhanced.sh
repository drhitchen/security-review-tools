#!/bin/bash
set -euo pipefail

WORKING_DIR="${HOME}/Downloads"
INSTALL_DIR="/usr/local/bin"
QUERIES_INSTALL_DIR="/usr/local/share/kics/assets"
REPO_URL="https://github.com/Checkmarx/kics.git"
REPO_NAME="kics"
BINARY_PATH="./bin/kics"

echo "📥 Cloning the latest KICS repository..."
git clone --depth=1 "$REPO_URL" "$REPO_NAME"
cd "$REPO_NAME" || { echo "❌ Failed to enter cloned directory."; exit 1; }

echo "🔧 Running Go vendor to install dependencies..."
go mod vendor

echo "🔨 Building KICS binary..."
make build

if [[ ! -f "$BINARY_PATH" ]]; then
    echo "❌ Build failed. KICS binary not found at $BINARY_PATH"
    exit 1
fi

echo "📦 Installing KICS binary to $INSTALL_DIR..."
sudo install "$BINARY_PATH" "$INSTALL_DIR/kics"

echo "📁 Installing KICS queries to system directory..."
sudo mkdir -p "$QUERIES_INSTALL_DIR"
if [[ -d "$QUERIES_INSTALL_DIR/queries" ]]; then
    echo "🔄 Updating existing queries directory..."
    sudo rm -rf "$QUERIES_INSTALL_DIR/queries"
fi
sudo cp -r "./assets/queries" "$QUERIES_INSTALL_DIR/"
echo "✅ Installed $(find "$QUERIES_INSTALL_DIR/queries" -name "*.rego" | wc -l) KICS query files"

echo "✅ Verifying KICS installation..."
"$INSTALL_DIR/kics" --version

echo "🧪 Testing KICS with queries..."
# Create a simple test file
echo 'resource "aws_instance" "test" { ami = "ami-123456" }' > test.tf
echo "📋 Running test scan to verify queries are working..."
if "$INSTALL_DIR/kics" scan -p . --no-progress --queries-path "$QUERIES_INSTALL_DIR/queries" > /dev/null 2>&1; then
    echo "✅ KICS queries are working correctly"
else
    echo "⚠️  KICS installed but queries test failed - queries may not be fully functional"
fi
rm -f test.tf

echo "🧹 Cleaning up build directory..."
cd "$WORKING_DIR"
rm -rf "$REPO_NAME"

echo "📁 Returned to working directory: $WORKING_DIR"
echo ""
echo "🎉 KICS installation completed successfully!"
echo ""
echo "📍 KICS binary installed at: $INSTALL_DIR/kics"
echo "📍 KICS queries installed at: $QUERIES_INSTALL_DIR/queries"
echo ""
echo "💡 Usage examples:"
echo "   kics scan -p /path/to/your/project --no-progress"
echo "   kics scan -p . --queries-path $QUERIES_INSTALL_DIR/queries"
echo ""