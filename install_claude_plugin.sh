#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || pwd)"
PLUGIN_DIR="${SCRIPT_DIR}"
MARKETPLACE_NAME="${GITHUB_SKILLS_MARKETPLACE_NAME:-github-skills-local}"
PLUGIN_NAME="github-skills"

# ── 1. Check required commands ────────────────────────────────────────────────
_require() {
  if ! command -v "$1" &>/dev/null; then
    echo "ERROR: '$1' not found. Please install it and try again." >&2
    [[ -n "${2:-}" ]] && echo "       $2" >&2
    exit 1
  fi
  echo "✓ $1: $(command -v "$1")"
}

_require git   "https://git-scm.com/downloads"
_require claude "https://claude.ai/code"

# ── 2. Register marketplace ───────────────────────────────────────────────────
if claude plugin marketplace list 2>/dev/null | grep -q "^  ❯ ${MARKETPLACE_NAME}"; then
  echo "✓ marketplace '${MARKETPLACE_NAME}': already registered"
else
  echo "→ registering marketplace '${MARKETPLACE_NAME}': ${PLUGIN_DIR}"
  claude plugin marketplace add "${PLUGIN_DIR}"
  echo "✓ marketplace '${MARKETPLACE_NAME}': registered"
fi

# ── 3. Remove existing installation ──────────────────────────────────────────
if claude plugin list 2>/dev/null | grep -q "❯ ${PLUGIN_NAME}@"; then
  echo "→ uninstalling existing '${PLUGIN_NAME}' plugin"
  claude plugin uninstall "${PLUGIN_NAME}" --yes
  echo "✓ '${PLUGIN_NAME}': uninstalled"
else
  echo "✓ '${PLUGIN_NAME}': not installed (skip uninstall)"
fi

# ── 4. Install plugin ─────────────────────────────────────────────────────────
echo "→ installing '${PLUGIN_NAME}@${MARKETPLACE_NAME}'"
claude plugin install "${PLUGIN_NAME}@${MARKETPLACE_NAME}"
echo "✓ '${PLUGIN_NAME}@${MARKETPLACE_NAME}': installed"

echo ""
echo "Installation complete. Restart Claude Code to activate the plugin."
