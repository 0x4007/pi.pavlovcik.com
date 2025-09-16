#!/usr/bin/env bash
set -Eeuo pipefail

# Simple deploy helper to update the Pi service quickly during testing.
# Defaults:
#   PI_USER=pi PI_HOST=pi.local
#   PI_PATH_META=/home/pi/repos/pi.pavlovcik.com
#   PI_PATH_AGENT=/home/pi/repos/pi-agent
#
# Usage:
#   scripts/deploy-pi.sh           # scp server file to both paths and restart
#   PI_HOST=pi.lan scripts/deploy-pi.sh

PI_USER=${PI_USER:-pi}
PI_HOST=${PI_HOST:-pi.local}
PI_SSH="${PI_USER}@${PI_HOST}"
PI_PATH_META=${PI_PATH_META:-/home/pi/repos/pi.pavlovcik.com}
PI_PATH_AGENT=${PI_PATH_AGENT:-/home/pi/repos/pi-agent}

LOCAL_FILE="submodules/pi-agent/server/kv_server.ts"

if [[ ! -f "$LOCAL_FILE" ]]; then
  echo "Error: $LOCAL_FILE not found. Run from repo root." >&2
  exit 1
fi

echo "Creating log dir on Pi (if missing) ..."
ssh "$PI_SSH" 'sudo mkdir -p /var/lib/pi-agent/logs && sudo chown pi:pi /var/lib/pi-agent/logs' || true

echo "Pushing server file to meta repo path ..."
scp "$LOCAL_FILE" "$PI_SSH:$PI_PATH_META/submodules/pi-agent/server/kv_server.ts" || true

echo "Pushing server file to standalone repo path ..."
scp "$LOCAL_FILE" "$PI_SSH:$PI_PATH_AGENT/server/kv_server.ts" || true

echo "Restarting service ..."
ssh "$PI_SSH" 'sudo systemctl restart pi-agent-deno.service && sleep 1 && systemctl status --no-pager -l pi-agent-deno.service | tail -n 80'

echo "Done. Health check:"
curl -fsS "http://$PI_HOST:3000/health/ready" || true

echo "Installing e2e helper script on Pi ..."
ssh "$PI_SSH" 'mkdir -p ~/scripts && chmod 755 ~/scripts' || true
scp scripts/e2e-on-pi.sh "$PI_SSH:~/scripts/e2e-on-pi.sh" && ssh "$PI_SSH" 'chmod +x ~/scripts/e2e-on-pi.sh'
