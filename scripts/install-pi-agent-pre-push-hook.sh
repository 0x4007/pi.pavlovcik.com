#!/usr/bin/env bash
set -Eeuo pipefail

# Install the pi-agent submodule pre-push hook that syncs the Pi after push.
# Usage:
#   scripts/install-pi-agent-pre-push-hook.sh

ROOT_DIR=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
HOOK_DIR="$ROOT_DIR/.git/modules/submodules/pi-agent/hooks"
SRC_HOOK="$ROOT_DIR/scripts/hooks/pre-push.pi-agent.git-pull.example"

if [ ! -f "$SRC_HOOK" ]; then
  echo "Hook example not found: $SRC_HOOK" >&2
  exit 1
fi

mkdir -p "$HOOK_DIR"
cp "$SRC_HOOK" "$HOOK_DIR/pre-push"
chmod +x "$HOOK_DIR/pre-push"

echo "Installed pi-agent pre-push hook to $HOOK_DIR/pre-push"
echo "Push from submodules/pi-agent to trigger Pi auto-sync via git pull."

