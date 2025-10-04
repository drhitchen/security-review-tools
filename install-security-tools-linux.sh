#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# 📁 Config for Linux installation using modular framework
REPO_URL="https://github.com/drhitchen/security-review-tools.git"
BASE_DIR="${HOME}/git/personal"
REPO_NAME="security-review-tools"
TARGET_DIR="${BASE_DIR}/${REPO_NAME}"

# Path to the modular installation framework
INSTALL_FRAMEWORK_DIR="${HOME}/Downloads/install"

# Python version for virtual environment
PYTHON_VERSION="3.12.11"

# ─────────────────────────────────────────────────────────────
# 🧪 Pre-flight check: ensure script has admin if needed
if ! sudo -v; then
echo "❌ This script requires sudo privileges. Exiting."
exit 1
fi

# ─────────────────────────────────────────────────────────────
# 📦 Clone or update repo
mkdir -p "${BASE_DIR}"
if [ -d "${TARGET_DIR}/.git" ]; then
echo "📥 Repository already exists. Pulling latest changes..."
git -C "${TARGET_DIR}" pull
else
echo "📥 Cloning repository into ${TARGET_DIR}..."
git clone "${REPO_URL}" "${TARGET_DIR}"
fi

# ─────────────────────────────────────────────────────────────
# 🔧 Check if modular installation framework exists
if [ ! -d "$INSTALL_FRAMEWORK_DIR" ]; then
echo "❌ Modular installation framework not found at $INSTALL_FRAMEWORK_DIR"
echo "Please ensure you have the modular installation scripts available."
exit 1
fi

# ─────────────────────────────────────────────────────────────
# 🐍 Ensure pyenv is installed and configured
if ! command -v pyenv >/dev/null 2>&1; then
echo "❌ pyenv not found. Running base installation..."
cd "$INSTALL_FRAMEWORK_DIR"
./00-pre-install.sh
else
echo "🐍 pyenv found."
fi

# Initialize pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# ─────────────────────────────────────────────────────────────
# 🧪 Set up virtual environment for security-review-tools
echo "🐍 Creating virtualenv in ${TARGET_DIR}/.venv"
pushd "$TARGET_DIR" >/dev/null

# Check if Python version is installed
if [ ! -d "$HOME/.pyenv/versions/$PYTHON_VERSION" ]; then
    echo "Installing Python $PYTHON_VERSION via pyenv..."
    pyenv install "$PYTHON_VERSION"
fi

# Create virtual environment
"$PYENV_ROOT/versions/$PYTHON_VERSION/bin/python" -m venv .venv
source .venv/bin/activate
echo "📦 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt
popd >/dev/null

# ─────────────────────────────────────────────────────────────
# 🔐 Install security tools via modular framework
echo "🔐 Installing security tools via modular installation framework..."
cd "$INSTALL_FRAMEWORK_DIR"

# Check which tools need to be installed
tools_to_install=(
    "install-build-tools.sh"
    "install-bearer.sh"
    "install-checkov.sh"
    "install-detect-secrets.sh"
    "install-kics.sh"
    "install-scc.sh"
    "install-semgrep.sh"
    "install-snyk.sh"
    "install-terrascan.sh"
    "install-trivy.sh"
    "install-trufflehog.sh"
)

# Install each tool
for tool_script in "${tools_to_install[@]}"; do
    if [ -f "$tool_script" ]; then
        echo "📦 Running $tool_script..."
        ./"$tool_script"
    else
        echo "⚠️  Warning: $tool_script not found, skipping..."
    fi
done

# ─────────────────────────────────────────────────────────────
# ✅ Manual authentication reminders
echo -e "\n🔐 Final step: log in to tools that require auth."
echo "➡️ Run this to log into Semgrep:"
echo " semgrep login"
echo "➡️ Run this to authenticate Snyk:"
echo " snyk auth"
echo " (Then enable 'code' scanning in Snyk web UI)"

# ─────────────────────────────────────────────────────────────
echo -e "\n✅ Install complete! Run ./check-security-tools.sh to verify everything."
echo "🔧 To use the tools, activate the virtual environment first:"
echo " cd ${TARGET_DIR}"
echo " source .venv/bin/activate"
