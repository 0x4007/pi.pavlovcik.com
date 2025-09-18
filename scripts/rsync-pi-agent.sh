#!/usr/bin/env bash
set -Eeuo pipefail

# Rsync Pi Agent code to the Raspberry Pi for rapid iteration.
# - Syncs selected subpaths from local submodules/pi-agent to ~/repos/pi-agent
# - Restarts systemd service after sync
#
# Env vars:
#   PI_USER=pi
#   PI_HOST=pi.local
#   PI_AGENT_DIR=/home/pi/repos/pi-agent
#   LOCAL_PI_AGENT_DIR=submodules/pi-agent
#   RSYNC_ONLY="server docs public README.md"   # optional space-separated list relative to LOCAL_PI_AGENT_DIR
#
# Usage:
#   scripts/rsync-pi-agent.sh                 # sync defaults (server, public, docs, README)
#   RSYNC_ONLY="server/kv_server.ts" scripts/rsync-pi-agent.sh

PI_USER=${PI_USER:-pi}
PI_HOST=${PI_HOST:-pi.local}
PI_SSH="${PI_USER}@${PI_HOST}"
PI_AGENT_DIR=${PI_AGENT_DIR:-/home/pi/repos/pi-agent}
LOCAL_PI_AGENT_DIR=${LOCAL_PI_AGENT_DIR:-submodules/pi-agent}

if [[ ! -d "$LOCAL_PI_AGENT_DIR" ]]; then
  echo "Local dir not found: $LOCAL_PI_AGENT_DIR" >&2
  exit 1
fi

DEFAULT_PATHS=(server public docs README.md)
read -r -a PATHS <<< "${RSYNC_ONLY:-${DEFAULT_PATHS[*]}}"

echo "Ensuring remote dir: $PI_AGENT_DIR"
ssh "$PI_SSH" "mkdir -p '$PI_AGENT_DIR'"

for rel in "${PATHS[@]}"; do
  SRC="$LOCAL_PI_AGENT_DIR/$rel"
  DST="$PI_SSH:$PI_AGENT_DIR/$(dirname "$rel")/"
  echo "Syncing $SRC -> $DST"
  rsync -az --compress --mkpath --info=stats1,progress2 \
    --exclude '.git' --exclude '.DS_Store' \
    -e ssh "$SRC" "$DST"
done

echo "Creating log dir on Pi (if missing) ..."
ssh "$PI_SSH" 'sudo mkdir -p /var/lib/pi-agent/logs && sudo chown pi:pi /var/lib/pi-agent/logs' || true

if [[ -f docs/runtime/AGENTS-RUNTIME.md ]]; then
  echo "Syncing runtime AGENTS.md to Pi work dir ..."
  PI_USER="$PI_USER" PI_HOST="$PI_HOST" PI_WORK_DIR="/var/lib/pi-agent/work" \
    SRC_FILE="docs/runtime/AGENTS-RUNTIME.md" \
    bash scripts/sync-agents-md.sh || true
fi

echo "Restarting service ..."
ssh "$PI_SSH" 'sudo systemctl restart pi-agent-deno.service && sleep 1 && systemctl status --no-pager -l pi-agent-deno.service | tail -n 80'

echo "Health check:"
curl -fsS "http://$PI_HOST:3000/health/ready" || true
