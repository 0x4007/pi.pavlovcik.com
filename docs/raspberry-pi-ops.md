# Raspberry Pi Operations

This is a LAN-hosted `deno_server` running on `pi.local:3000`. Use these commands to inspect, update, and recover the service.

## Access

- SSH: `ssh pi@pi.local`
- Privileged ops: prefix commands with `sudo` when required.

## Service

- Unit name: `pi-agent-deno.service`
- Logs (journal): `journalctl -u pi-agent-deno.service -f`
- Logs (files): `/var/lib/pi-agent/logs/`
  - Codex calls: `/var/lib/pi-agent/logs/codex-YYYY-MM-DD.jsonl`
  - Latest event: `/var/lib/pi-agent/logs/codex-latest.json`
  - Tail today: `tail -f /var/lib/pi-agent/logs/codex-$(date +%F).jsonl`
- Log dir override: set `PI_AGENT_LOG_DIR=/some/path` in a systemd drop-in.
- Restart: `sudo systemctl restart pi-agent-deno.service`
- Status: `systemctl status pi-agent-deno.service`
- Health: `curl http://pi.local:3000/health/ready`

The current OS-level layout, hardening, and timers are documented in:

- `submodules/pi-agent/docs/os-server-setup.md` (source of truth for unit details)

## Paths and environment

- Repo checkout: typically under `/home/pi/repos/`.
- KV storage: `DENO_KV_PATH=/var/lib/pi-agent/kv.sqlite3`
- Ensure PATH includes `codex` and `gh` for the unit.
- Codex work dir: `PI_AGENT_WORK_DIR=/var/lib/pi-agent/work`
  - The server creates this directory if missing.
  - Runtime AGENTS.md is managed from this repo at `docs/runtime/AGENTS-RUNTIME.md` and synced to `/var/lib/pi-agent/work/AGENTS.md`.
  - Use `scripts/sync-agents-md.sh` or enable the example post-push hook `scripts/hooks/post-push.sync-agents-md.example`.
  - Server does not auto-create AGENTS.md; manage it via the sync script or hook.

## Auto-sync on push (pi-agent only)

- Install the submodule pre-push hook to auto pull on the Pi after your push completes:

```
# From this repo root
scripts/install-pi-agent-pre-push-hook.sh
```

- Then push from the pi-agent submodule:

```
cd submodules/pi-agent
git push
```

- The hook waits until the new SHA is visible on your remote (default `origin/<branch>`), then pulls on the Pi (`/home/pi/repos/pi-agent`) and restarts `pi-agent-deno.service`.
- Customize with env vars when pushing (optional): `PI_USER`, `PI_HOST`, `PI_DIR`, `TIMEOUT_SECS`.

## Deploy updates

Fast rsync-based deploys (recommended during iteration):

```
# From this repo root
scripts/rsync-pi-agent.sh                      # sync server/, public/, docs/, README
RSYNC_ONLY="server/kv_server.ts" scripts/rsync-pi-agent.sh  # sync just the server file
```

Classic git-based deploy (if you also manage the repo on the Pi):

```
ssh pi@pi.local
cd /home/pi/repos/pi-agent
git pull --ff-only
sudo systemctl restart pi-agent-deno.service
```

Validate: `curl http://pi.local:3000/health && curl -s http://pi.local:3000/kv/test | jq`.

## API smoke tests

- Codex:

```
curl -sS -X POST http://pi.local:3000/api/codex \
  -H 'content-type: application/json' \
  -d '{"prompt":"echo hello from codex"}' | jq
```

- KV:

```
curl -sS -X PUT http://pi.local:3000/kv/demo/key \
  -H 'content-type: application/json' \
  -d '{"value":"ok"}' | jq
```

## Troubleshooting

- Look for permission errors in `journalctl` (read/write paths, PATH to `codex`/`gh`).
- Confirm Deno version: `deno --version` (>= 1.44). Reboot only if the service cannot be restarted cleanly.

## Edit service configuration

- Safe drop-in override: `sudo systemctl edit pi-agent-deno.service` (adds files under `/etc/systemd/system/pi-agent-deno.service.d/`).
- After edits: `sudo systemctl daemon-reload && sudo systemctl restart pi-agent-deno.service`.
- Verify env: `systemctl cat pi-agent-deno.service` and inspect logs.

Example drop-in content:

```
[Service]
Environment=DENO_KV_PATH=/var/lib/pi-agent/kv.sqlite3
Environment=PATH=/usr/local/bin:/usr/bin:/bin
# Prefix posted comments with this handle (invokes kernel)
Environment=PI_AGENT_MENTION=@0x4007
# Codex working directory (kept outside this repo to avoid runtime AGENTS.md)
Environment=PI_AGENT_WORK_DIR=/var/lib/pi-agent/work
# Runtime AGENTS.md is managed via sync script; no server-side bootstrap.
# Optional: cap posted comment length (keep tail)
# Environment=PI_POST_CHAR_CAP=1200
# Optional, for headless gh auth
# Environment=GH_TOKEN=ghp_xxx
```
