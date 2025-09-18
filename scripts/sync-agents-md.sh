#!/usr/bin/env bash
set -Eeuo pipefail

# Sync the repo's runtime AGENTS.md to the Pi work dir.
# Source file: docs/runtime/AGENTS-RUNTIME.md
# Destination:  /var/lib/pi-agent/work/AGENTS.md
#
# Env vars:
#   PI_USER=pi
#   PI_HOST=pi.local
#   PI_WORK_DIR=/var/lib/pi-agent/work
#   SRC_FILE=docs/runtime/AGENTS-RUNTIME.md
#
# Usage:
#   scripts/sync-agents-md.sh

PI_USER=${PI_USER:-pi}
PI_HOST=${PI_HOST:-pi.local}
PI_SSH="${PI_USER}@${PI_HOST}"
PI_WORK_DIR=${PI_WORK_DIR:-/var/lib/pi-agent/work}
SRC_FILE=${SRC_FILE:-docs/runtime/AGENTS-RUNTIME.md}

if [[ ! -f "$SRC_FILE" ]]; then
  echo "Source file not found: $SRC_FILE" >&2
  exit 1
fi

echo "Creating work dir on Pi (if missing): $PI_WORK_DIR"
ssh "$PI_SSH" "sudo mkdir -p '$PI_WORK_DIR' && sudo chown pi:pi '$PI_WORK_DIR'"

echo "Syncing $SRC_FILE -> $PI_SSH:$PI_WORK_DIR/AGENTS.md"
scp "$SRC_FILE" "$PI_SSH:$PI_WORK_DIR/AGENTS.md"

echo "Done. Remote path: $PI_WORK_DIR/AGENTS.md"

