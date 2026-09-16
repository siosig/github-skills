#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null || pwd)"
PLUGIN_DIR="${SCRIPT_DIR}"
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
_require agy   "Install agy CLI first"

# ── 2. Remove existing installation ──────────────────────────────────────────
if agy plugin list 2>/dev/null | grep -q "\"${PLUGIN_NAME}\""; then
  echo "→ uninstalling existing '${PLUGIN_NAME}' plugin"
  agy plugin uninstall "${PLUGIN_NAME}" >/dev/null || true
  echo "✓ '${PLUGIN_NAME}': uninstalled"
else
  echo "✓ '${PLUGIN_NAME}': not installed (skip uninstall)"
fi

# ── 3. Install plugin ─────────────────────────────────────────────────────────
echo "→ installing '${PLUGIN_NAME}' from ${PLUGIN_DIR}"
agy plugin install "${PLUGIN_DIR}"
echo "✓ '${PLUGIN_NAME}': installed"

echo ""
echo "Installation complete. Restart agy to activate the plugin."
