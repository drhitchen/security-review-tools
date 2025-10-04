#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# 📁 Config
REPO_URL="https://github.com/drhitchen/security-review-tools.git"
BASE_DIR="${HOME}/git/personal"
REPO_NAME="security-review-tools"
TARGET_DIR="${BASE_DIR}/${REPO_NAME}"

# Find latest 3.12.x version
echo "🐍 Finding latest Python 3.12 version..."
PYTHON_VERSION=$(pyenv install --list | grep "^  3.12" | tail -1 | tr -d '[:space:]')
echo "🐍 Found latest Python 3.12 version: $PYTHON_VERSION"

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
# 🍺 Ensure Homebrew is installed
if ! command -v brew >/dev/null 2>&1; then
echo "❌ Homebrew not found. Please install it from your company portal and rerun this script."
exit 1
else
echo "🍺 Homebrew found."
fi
echo "🔄 Updating Homebrew..."
brew update

# ─────────────────────────────────────────────────────────────
# 🐍 Install pyenv and required Python versions
echo "🐍 Installing pyenv (if needed)..."
brew install pyenv || true
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
echo "🐍 Installing Python $PYTHON_VERSION via pyenv..."
pyenv install -s "$PYTHON_VERSION"
pyenv global "$PYTHON_VERSION"

# ─────────────────────────────────────────────────────────────
# 🧪 Set up virtual environment
echo "🐍 Creating virtualenv in ${TARGET_DIR}/.venv"
pushd "$TARGET_DIR" >/dev/null
"$PYENV_ROOT/versions/$PYTHON_VERSION/bin/python" -m venv .venv
source .venv/bin/activate
echo "📦 Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt
popd >/dev/null

# ─────────────────────────────────────────────────────────────
# 🔧 Install security tools via Homebrew
echo "🔐 Installing Homebrew security tools..."
brew tap bearer/tap || true
brew install bearer/tap/bearer
brew install checkov
brew install code2prompt
brew install detect-secrets
brew install glow
brew install jq
brew install kics
brew install mdcat
brew install pyenv
brew install scc
brew install semgrep
brew tap snyk/tap || true
brew install snyk-cli
brew install sslscan
brew install terrascan
brew install trivy
brew install trufflehog
echo "📈 Upgrading and cleaning up Homebrew packages..."
brew upgrade
brew cleanup

# ─────────────────────────────────────────────────────────────
# ✅ Manual authentication reminders
echo -e "\n🔐 Final step: log in to tools that require auth."
echo "➡️ Run this to log into Semgrep:"
echo " semgrep login"
echo "➡️ Run this to authenticate Snyk:"
echo " snyk auth"
echo " (Then enable 'code' scanning in Snyk web UI)"

# ─────────────────────────────────────────────────────────────
echo -e "\n✅ Install complete! Run ./check-tools.sh to verify everything."
