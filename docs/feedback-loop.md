# End-to-End Feedback Loop

This guide sets up a realistic E2E test: a comment in a test repo triggers your personal-agent workflow, which calls the Pi `/api/codex`. The Pi runs Codex and posts a GitHub comment via `gh`. You observe both GitHub Actions and Pi logs, iterate, and fix issues quickly.

## Prerequisites
- Pi server running on `pi.local:3000` (or public tunnel), with:
  - `codex` and `gh` installed and authenticated (`gh auth status`)
  - `DENO_KV_PATH` persisted (see raspberry-pi-ops.md)
- Personal Agent repo configured (branch `pi-integration`) with secret:
  - `PI_URL` set to your Pi base URL (e.g., `https://pi.pavlovcik.com`)
- UbiquityOS GitHub App + bridge installed on your test repo with plugin config

## 1) Use a single test repo and open issues
- We reuse one repo to avoid clutter: `0x4007/pi-e2e-test`.
- If it doesn't exist, the Pi helper can create it automatically.
- Open a fresh issue per test run:
```
gh issue create -R 0x4007/pi-e2e-test -t "E2E test $(date --iso-8601=seconds)" -b "Test end-to-end with Pi Codex"
```

## 2) Trigger the flow
- In the issue, comment: `@0x4007 Summarize this issue and suggest next steps.`
- The GitHub App routes to kernel → bridge → dispatches `0x4007/personal-agent` `compute` workflow.
- The workflow calls your Pi `/api/codex` with repo/issue; the Pi runs Codex and posts a comment via `gh`.

## 3) Observe logs
- Personal Agent (Actions):
```
gh run watch -R 0x4007/personal-agent -B pi-integration
```
- Pi server:
```
ssh pi@pi.local
journalctl -u pi-agent-deno.service -f -o cat
# Look for lines like: [api/codex] start ... and [api/codex] done code=... posted=...
ls -la /var/lib/pi-agent/logs
tail -f /var/lib/pi-agent/logs/codex-$(date +%F).jsonl
cat /var/lib/pi-agent/logs/codex-latest.json | sed -n '1,80p'
```

## 4) Iterate quickly
- Tweak prompt shaping in `submodules/personal-agent/src/handlers/codex-agent.ts`.
- Adjust Pi logging or Codex CLI flags if needed.
- Push changes to `pi-integration`; CI builds dist; re-run the comment.

## 5) Sanity checks
- Health: `curl -s http://pi.local:3000/health/ready | jq`
- Direct Codex: `curl -s -X POST $PI_URL/api/codex -H 'content-type: application/json' -d '{"prompt":"echo hello"}' | jq`
